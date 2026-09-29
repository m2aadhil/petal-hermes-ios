import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Bindable var model: AppModel
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var attachmentContext = ""
    @State private var destination: AppDestination?
    @State private var pinnedToBottom = true
    @State private var draggingHistory = false
    @State private var bottomVisible = true
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if model.transcript.messages.isEmpty { emptyChat }
                else { messages }
            }
            .background(DS.Palette.background)
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $destination) { page in
                SpacesView(model: model, initial: page == .spaces ? nil : page)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(DS.Radius.sheet)
            }
            .photosPicker(isPresented: $showPhotos, selection: $photos, maxSelectionCount: max(1, 4 - model.attachments.count), matching: .images)
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                let context = attachmentContext
                Task {
                    model.importingAttachments = true
                    defer { model.importingAttachments = false }
                    do {
                        for url in try result.get() {
                            let access = url.startAccessingSecurityScopedResource()
                            defer { if access { url.stopAccessingSecurityScopedResource() } }
                            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                            guard size <= DraftAttachment.maximumBytes else { throw RPCFailure(String(localized: "Choose a file of 10 MB or less.")) }
                            let data = try await Task.detached { try Data(contentsOf: url) }.value
                            try await model.addAttachment(data: data, name: url.lastPathComponent, mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", context: context)
                        }
                    } catch is CancellationError { }
                    catch { model.notice = error.localizedDescription }
                }
            }
            .onChange(of: photos) { _, items in
                guard !items.isEmpty else { return }
                let context = attachmentContext
                Task {
                    model.importingAttachments = true
                    defer { model.importingAttachments = false; photos = [] }
                    do {
                        for item in items {
                            guard let data = try await item.loadTransferable(type: Data.self) else { throw RPCFailure(String(localized: "This photo isn’t available.")) }
                            let jpeg = try await Task.detached { try PhotoAttachment.jpeg(data) }.value
                            try await model.addAttachment(data: jpeg, name: "Photo-\(UUID().uuidString.prefix(8)).jpg", mimeType: "image/jpeg", context: context)
                        }
                    } catch is CancellationError { }
                    catch { model.notice = error.localizedDescription }
                }
            }
            .onChange(of: model.draft) { _, _ in model.draftChanged() }
            .onChange(of: model.selected?.storedID) { _, _ in pinnedToBottom = true }
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.s) {
            Button { present(.profiles) } label: {
                HStack(spacing: DS.Space.s) {
                    AgentAvatar(name: model.agent?.name ?? "default", size: 34)
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        HStack(spacing: DS.Space.xxs + 2) {
                            Text(model.agent?.title ?? "Hermes").textStyle(.headline)
                            Image(systemName: "chevron.down").icon(.xs, weight: .semibold).foregroundStyle(DS.Palette.textTertiary)
                        }
                        ConnectionIndicator(model: model).lineLimit(1)
                    }
                }
            }.buttonStyle(PressableStyle()).accessibilityLabel("Choose an agent").accessibilityIdentifier("quick-agents")
            Spacer()
            IconButton("square.and.pencil", label: "New conversation") { model.newChat(); focused = true }
        }.padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.xs).padding(.bottom, DS.Space.m)
    }

    private func present(_ page: AppDestination) {
        focused = false
        destination = page
    }

    private var emptyChat: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                Spacer(minLength: 64)
                AgentMark(size: 48)
                Text("A little room\nfor your ideas.").textStyle(.hero).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A question, a wish, a project.\nHermes picks up the thread with you.")
                    .textStyle(.body).foregroundStyle(DS.Palette.textSecondary)
                VStack(spacing: DS.Space.s) {
                    suggestion("Take stock", subtitle: "Find what matters today", symbol: "sun.max", prompt: String(localized: "Help me take stock and choose my priorities for today."))
                    suggestion("Explore an idea", subtitle: "Let curiosity lead the way", symbol: "sparkle", prompt: String(localized: "I have an idea to explore. Help me sharpen it."))
                    suggestion("Take action", subtitle: "Just one first step", symbol: "arrow.up.right", prompt: String(localized: "Help me turn my project into a concrete first step."))
                }.padding(.top, DS.Space.s)
            }.padding(DS.Space.xxl).readableWidth(640)
        }.scrollDismissesKeyboard(.interactively)
    }

    private func suggestion(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String, prompt: String) -> some View {
        Button { model.draft = prompt; focused = true } label: {
            HStack(spacing: DS.Space.s + 2) {
                IconTile(symbol: symbol, size: 36)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(title).textStyle(.label).foregroundStyle(DS.Palette.textPrimary)
                    Text(subtitle).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.left").icon(.s).foregroundStyle(DS.Palette.textTertiary).accessibilityHidden(true)
            }.padding(DS.Space.m).tile(radius: DS.Radius.l)
        }.buttonStyle(PressableStyle())
    }

    private var messages: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Space.xxl) {
                        ForEach(model.transcript.messages) { message in
                            MessageView(message: message, agent: model.agent?.title ?? "Hermes")
                                .equatable().id(message.id)
                        }
                        if let activity = model.transcript.activity, model.transcript.running {
                            HStack(spacing: DS.Space.xs) {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(DS.Palette.accent)
                                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                                    .accessibilityHidden(true)
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(model.sending ? String(localized: "Sending to Hermes…")
                                         : model.state == .connected && model.transcript.isWaitingForResponse(at: context.date)
                                         ? String(localized: "Waiting for the model’s response…") : activity)
                                        .lineLimit(2)
                                }
                            }.textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).padding(.leading, DS.Space.hairline)
                        }
                        if let failure = model.transcript.failure, !failure.isEmpty {
                            InlineMessage(failure)
                        }
                        if let approval = model.transcript.approval { ApprovalCard(payload: approval, model: model) }
                        if let clarification = model.transcript.clarification { ClarificationCard(payload: clarification, model: model) }
                        if let credential = model.transcript.credential { CredentialCard(payload: credential, model: model) }
                        Color.clear.frame(height: 1).id("bottom").background(GeometryReader { marker in
                            Color.clear.preference(key: BottomPreference.self, value: marker.frame(in: .named("chat-scroll")).maxY)
                        })
                    }.padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.s).padding(.bottom, DS.Space.l).readableWidth(DS.Size.chatWidth)
                }
                .coordinateSpace(name: "chat-scroll")
                .scrollDismissesKeyboard(.interactively)
                .chatScrollAnchors()
                .simultaneousGesture(DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        draggingHistory = true
                        if value.translation.height > 5 { pinnedToBottom = false }
                    }
                    .onEnded { _ in draggingHistory = false; if bottomVisible { pinnedToBottom = true } })
                .onPreferenceChange(BottomPreference.self) { y in
                    bottomVisible = y <= geo.size.height + 55
                    if !draggingHistory, bottomVisible { pinnedToBottom = true }
                    if pinnedToBottom, !draggingHistory, y > geo.size.height + 1 { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: model.transcript.messages.last?.text) { _, _ in
                    if pinnedToBottom, !draggingHistory { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: model.transcript.messages.count) { _, _ in
                    if pinnedToBottom { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { proxy.scrollTo("bottom", anchor: .bottom) } }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !pinnedToBottom {
                        IconButton("arrow.down", label: "Latest message") {
                            pinnedToBottom = true
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                        }.elevation(.floating).padding(DS.Space.l)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if model.draft.hasSuffix("@") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.xs) {
                        ForEach(model.profiles) { agent in
                            Button { model.draft += agent.name + " " } label: {
                                HStack(spacing: DS.Space.xxs + 2) { AgentAvatar(name: agent.name, size: 24); Text(agent.title).textStyle(.caption) }
                                    .padding(DS.Space.xs).background(DS.Palette.surface, in: Capsule())
                                    .overlay(Capsule().strokeBorder(DS.Palette.line))
                            }.buttonStyle(PressableStyle())
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                if !model.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.xs) {
                            ForEach(model.attachments) { item in
                                HStack(spacing: DS.Space.xxs + 2) {
                                    Image(systemName: item.isImage ? "photo" : "doc")
                                    Text(item.name).lineLimit(1).frame(maxWidth: 140)
                                    Button { model.removeAttachment(item) } label: {
                                        Image(systemName: "xmark").frame(width: 32, height: 44)
                                    }.disabled(model.sending).accessibilityLabel("Remove \(item.name)")
                                }.textStyle(.caption).padding(.leading, DS.Space.s).background(DS.Palette.sunken, in: RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                            }
                        }
                    }.padding(.horizontal, DS.Space.xxs).accessibilityIdentifier("pending-attachments")
                }
                if model.importingAttachments { ProgressView("Adding…").textStyle(.caption).padding(DS.Space.xs) }
                TextField("Message…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...7).textStyle(.body).focused($focused)
                    .padding(.horizontal, DS.Space.xs).padding(.vertical, DS.Space.xs).frame(minHeight: DS.Size.tap)
                    .accessibilityIdentifier("chat-composer")
                HStack(spacing: DS.Space.xxs) {
                    ViewThatFits(in: .horizontal) {
                        composerShortcuts(showToolTitle: true)
                        composerShortcuts(showToolTitle: false)
                    }
                    Spacer(minLength: 0)
                    Button { present(.voice) } label: {
                        Image(systemName: "mic").icon(.l).frame(width: DS.Size.tap, height: DS.Size.tap)
                            .foregroundStyle(DS.Palette.accent)
                    }.buttonStyle(.plain).accessibilityLabel("Voice conversation").accessibilityIdentifier("voice-mode")
                        .disabled(model.sending || model.opening || model.transcript.running || (!model.demo && model.state != .connected))
                    sendButton
                }
            }.padding(DS.Space.xs + 2)
                .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous).strokeBorder(DS.Palette.line))
                .elevation(.floating)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("composer-surface")
        }.padding(.horizontal, DS.Space.m).padding(.top, DS.Space.xs).padding(.bottom, DS.Space.xs).readableWidth(DS.Size.chatWidth + 2 * DS.Space.m)
            .background(DS.Palette.background)
    }

    private var messageActions: some View {
        Menu {
            Button("Add a photo", systemImage: "photo") { focused = false; attachmentContext = model.attachmentContext; showPhotos = true }
            Button("Add a file", systemImage: "doc") { focused = false; attachmentContext = model.attachmentContext; showFiles = true }
        } label: {
            Image(systemName: "plus").icon(.l)
                .foregroundStyle(DS.Palette.textSecondary).frame(width: DS.Size.tap, height: DS.Size.tap)
        }.disabled(model.sending || model.importingAttachments || model.attachments.count >= 4).accessibilityLabel("Add an attachment").accessibilityIdentifier("message-actions")
    }

    private func composerShortcuts(showToolTitle: Bool) -> some View {
        HStack(spacing: DS.Space.hairline) {
            messageActions
            Button { present(.history) } label: {
                Image(systemName: "bubble.left.and.bubble.right").icon(.m)
                    .frame(width: DS.Size.tap, height: DS.Size.tap)
            }.accessibilityLabel("Conversations for the active profile").accessibilityIdentifier("quick-history")
            Button { present(.spaces) } label: {
                HStack(spacing: DS.Space.xxs + 2) {
                    Image(systemName: "slider.horizontal.3").icon(.m)
                    if showToolTitle { Text("Tools") }
                }.padding(.horizontal, showToolTitle ? DS.Space.xs : 0).frame(minWidth: DS.Size.tap, minHeight: DS.Size.tap)
            }.accessibilityLabel("Tools").accessibilityIdentifier("app-navigation")
        }.textStyle(.captionEmphasis).foregroundStyle(DS.Palette.textSecondary).buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var sendButton: some View {
        Button {
            Task {
                if model.transcript.running { await model.interrupt() }
                else { pinnedToBottom = true; focused = false; await model.send() }
            }
        } label: {
            Image(systemName: model.transcript.running ? "stop.fill" : "arrow.up")
                .icon(model.transcript.running ? .s : .m, weight: .semibold)
                .foregroundStyle(DS.Palette.onAccent).frame(width: DS.Size.tap, height: DS.Size.tap)
                .background(model.canSend || model.transcript.running ? DS.Palette.accent : DS.Palette.disabledFill, in: Circle())
        }.buttonStyle(PressableStyle()).disabled(!model.canSend && !model.transcript.running)
            .accessibilityLabel(model.transcript.running ? "Stop the response" : "Send")
            .accessibilityIdentifier("send-message")
    }

}

struct CredentialCard: View {
    let payload: JSONValue
    let model: AppModel
    @State private var value = ""
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Label(payload["event_type"].string == "sudo.request" ? "Administrator access requested" : "Hermes is asking for a secret", systemImage: "key").textStyle(.headline)
            if !payload["prompt"].string.isEmpty { Text(payload["prompt"].string).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary) }
            SecureField("Value sent directly to Hermes", text: $value).fieldStyle()
            HStack {
                Button("Cancel") { respond("") }.buttonStyle(.bordered)
                Spacer()
                Button("Submit") { respond(value) }.buttonStyle(.borderedProminent).disabled(value.isEmpty)
            }.disabled(busy)
            Label("This value won’t be kept in the local history.", systemImage: "lock").textStyle(.footnote).foregroundStyle(DS.Palette.textSecondary)
        }.card()
    }
    private func respond(_ text: String) {
        busy = true
        Task { await model.answerCredential(text); value = ""; busy = false }
    }
}

private struct BottomPreference: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct MessageView: View, Equatable {
    let message: ChatMessage
    let agent: String
    private var user: Bool { message.role == "user" }
    var body: some View {
        HStack(alignment: .top) {
            if user { Spacer(minLength: 42) }
            VStack(alignment: .leading, spacing: DS.Space.s - 2) {
                if !user {
                    HStack(spacing: DS.Space.xs) { AgentMark(size: 17); Text(agent).textStyle(.sectionLabel).foregroundStyle(DS.Palette.textSecondary) }
                }
                Group {
                    if user { Text(verbatim: message.text).textStyle(.body) }
                    else { MarkdownText(text: message.text) }
                }
                    .textSelection(.enabled)
                    .padding(user ? DS.Space.m : 0)
                    .background(user ? DS.Palette.surface : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous).strokeBorder(user ? DS.Palette.line : .clear))
                if message.delivery != .confirmed {
                    Text(message.delivery == .sending ? "Sending…" : message.delivery == .uncertain ? "Delivery unconfirmed. Check the history" : "Not sent · copy to try again")
                        .textStyle(.footnote).foregroundStyle(message.delivery == .sending ? DS.Palette.textSecondary : DS.Palette.critical)
                }
            }
            if !user { Spacer(minLength: 5) }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.text }
            ShareLink(item: message.text) { Label("Share", systemImage: "square.and.arrow.up") }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(user ? "user-message" : "assistant-message")
    }
}

struct ApprovalCard: View {
    let payload: JSONValue
    let model: AppModel
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Label("Hermes is asking for your approval", systemImage: "hand.raised").textStyle(.headline)
            Text(payload["command"].string).textStyle(.codeSmall).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(DS.Space.s)
                .background(DS.Palette.sunken, in: RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
            if !payload["reason"].string.isEmpty { Text(payload["reason"].string).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary) }
            HStack {
                Button("Deny") { answer("deny") }.buttonStyle(.bordered)
                Spacer()
                if payload["choices"].array.contains(.string("once")) {
                    Button("Allow once") { answer("once") }.buttonStyle(.borderedProminent)
                }
            }.textStyle(.captionEmphasis).disabled(busy)
        }.card()
    }
    private func answer(_ choice: String) { busy = true; Task { await model.answerApproval(choice); busy = false } }
}

struct ClarificationCard: View {
    let payload: JSONValue
    let model: AppModel
    @State private var answer = ""
    @State private var busy = false
    @State private var answered = Set<String>()
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Label("Your choice", systemImage: "bubble.left.and.text.bubble.right").textStyle(.headline)
            if payload["questions"].array.isEmpty {
                question(payload, qid: nil)
            } else {
                ForEach(Array(payload["questions"].array.enumerated()), id: \.offset) { _, q in
                    if !answered.contains(q["qid"].string) { question(q, qid: q["qid"].string) }
                }
            }
        }.card()
    }
    @ViewBuilder private func question(_ q: JSONValue, qid: String?) -> some View {
        Text(q["question"].string).textStyle(.subheadline)
        ForEach(Array(q["choices"].array.enumerated()), id: \.offset) { _, choice in
            Button(choice.string) { respond(choice.string, qid: qid) }.buttonStyle(.bordered).disabled(busy)
        }
        HStack {
            TextField("Your answer…", text: $answer).fieldStyle()
            Button { respond(answer, qid: qid) } label: { Image(systemName: "arrow.up.circle.fill").icon(.xl).frame(minWidth: DS.Size.tap, minHeight: DS.Size.tap) }.accessibilityLabel("Send").disabled(answer.isEmpty || busy)
        }
    }
    private func respond(_ text: String, qid: String?) {
        busy = true
        Task { await model.answerClarification(text, qid: qid); if let qid { answered.insert(qid) }; answer = ""; busy = false }
    }
}
