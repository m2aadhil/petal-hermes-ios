import SwiftUI

struct QuickProfilePicker: View {
    let model: AppModel
    var manage: () -> Void
    var close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(Text("Who are we talking to?"), subtitle: Text("Pick up the thread with each agent."), style: .title)
                .padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.xxl).padding(.bottom, DS.Space.m)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Space.xxs) {
                        ForEach(model.profiles) { agent in
                            Button {
                                close()
                                if agent.name != model.profile { Task { await model.openBot(agent) } }
                            } label: {
                                HStack(spacing: DS.Space.s) {
                                    AgentAvatar(name: agent.name, size: 38)
                                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                        Text(agent.title).textStyle(.label).foregroundStyle(DS.Palette.textPrimary)
                                        Text(agent.detail.isEmpty ? "@\(agent.name)" : agent.detail)
                                            .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if agent.name == model.profile {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Palette.accent).accessibilityHidden(true)
                                    }
                                }.padding(.horizontal, DS.Space.s + 2).padding(.vertical, DS.Space.s)
                                    .rowHighlight(agent.name == model.profile)
                            }.buttonStyle(PressableStyle()).disabled(model.opening || (!model.demo && model.state != .connected))
                                .accessibilityIdentifier("quick-profile-\(agent.name)")
                                .accessibilityAddTraits(agent.name == model.profile ? .isSelected : [])
                                .id(agent.name)
                        }
                    }.padding(.horizontal, DS.Space.m)
                }.onAppear { proxy.scrollTo(model.profile, anchor: .center) }
            }
            if !model.demo && model.state != .connected {
                InlineMessage(String(localized: "Reconnect to Hermes to switch agents."), kind: .info).padding(.horizontal, DS.Space.screen)
            }
            HStack {
                Button(action: manage) {
                    Label("Manage agents", systemImage: "person.crop.circle.badge.gearshape")
                        .textStyle(.label).foregroundStyle(DS.Palette.accentText).frame(minHeight: DS.Size.control)
                }.buttonStyle(PressableStyle()).accessibilityIdentifier("manage-agents")
                Spacer()
                IconButton("chevron.down", label: "Back to chat", scale: .medium, weight: .semibold, action: close)
                    .accessibilityIdentifier("return-to-chat")
            }.padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.s).padding(.bottom, DS.Space.s)
        }.background(DS.Palette.background)
    }
}

struct AgentsView: View {
    @Bindable var model: AppModel
    var openChat: () -> Void
    @State private var search = ""
    @State private var creating = false
    @State private var editing: AgentProfile?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    ScreenHeader(Text("Your agents."), subtitle: Text("One talent. One ongoing thread.")).padding(.top, DS.Space.s)
                    SearchField("Find an agent", text: $search)
                    VStack(spacing: DS.Space.xs) {
                        ForEach(model.profiles.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search) }) { agent in
                            HStack(spacing: 0) {
                                Button { openChat(); Task { await model.openBot(agent) } } label: {
                                    HStack(spacing: DS.Space.s + 2) {
                                        AgentAvatar(name: agent.name, size: 44)
                                        VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                            HStack(spacing: DS.Space.xs) {
                                                Text(agent.title).textStyle(.bodyEmphasis).foregroundStyle(DS.Palette.textPrimary)
                                                if model.profile == agent.name { StatusDot(color: DS.Palette.accent, size: 5) }
                                            }
                                            Text(agent.detail.isEmpty ? "@\(agent.name)" : agent.detail)
                                                .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(.leading, DS.Space.s + 2).padding(.vertical, DS.Space.m).contentShape(Rectangle())
                                }.buttonStyle(PressableStyle()).disabled(model.opening).accessibilityIdentifier("agent-\(agent.name)")
                                Button { editing = agent } label: {
                                    Image(systemName: "ellipsis").icon(.m, weight: .medium).foregroundStyle(DS.Palette.textSecondary)
                                        .frame(width: DS.Size.tap, height: DS.Size.control)
                                }.buttonStyle(PressableStyle()).accessibilityLabel("Edit \(agent.title)")
                            }.rowHighlight(agent.name == model.profile)
                        }
                    }
                    Label("Bot Mode · The same agent, everywhere.", systemImage: "arrow.triangle.branch")
                        .textStyle(.caption).foregroundStyle(DS.Palette.textTertiary).padding(.horizontal, DS.Space.s)
                }.padding(.horizontal, DS.Space.screen).padding(.bottom, DS.Space.xl).readableWidth()
            }.background(DS.Palette.background).toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ToolDock {
                        Button { creating = true } label: { Label("Create an agent", systemImage: "plus").frame(minHeight: 44) }
                            .disabled(model.demo)
                    }
                }
                .sheet(isPresented: $creating) { BotEditor(model: model) }
                .sheet(item: $editing) { BotEditor(model: model, bot: $0) }
        }
    }
}

struct ProfilePicker: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(model.profiles) { agent in
                Button {
                    Task { await model.changeProfile(agent.name); dismiss() }
                } label: {
                    HStack(spacing: DS.Space.s + 2) {
                        AgentAvatar(name: agent.name)
                        VStack(alignment: .leading, spacing: DS.Space.xxs) {
                            Text(agent.title).textStyle(.body).foregroundStyle(DS.Palette.textPrimary)
                            Text(agent.model).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                        }
                        Spacer()
                        if model.profile == agent.name { Image(systemName: "checkmark").foregroundStyle(DS.Palette.accent) }
                    }.padding(.vertical, DS.Space.xs)
                }
            }.modernList()
                .navigationTitle("Your profiles").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

struct SessionsView: View {
    let model: AppModel
    @State private var search = ""
    @State private var loading = false
    @State private var loadError: String?
    @State private var openingID: String?
    @State private var refreshID = UUID()
    @FocusState private var searching: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.toolNavigation) private var navigation

    private var conversations: [Conversation] {
        ConversationIndex.ordered(model.sessions.filter { $0.profile == model.profile })
    }
    private var filtered: [Conversation] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return conversations.filter { query.isEmpty || "\($0.title) \($0.preview)".localizedStandardContains(query) }
    }
    private var sections: [(title: String, rows: [Conversation])] {
        let calendar = Calendar.current
        let week = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: Date())) ?? Date()
        let grouped = Dictionary(grouping: filtered) { item -> Int in
            if calendar.isDateInToday(item.updated) { return 0 }
            if calendar.isDateInYesterday(item.updated) { return 1 }
            return item.updated >= week ? 2 : 3
        }
        return [String(localized: "Today"), String(localized: "Yesterday"), String(localized: "Previous 7 days"), String(localized: "Earlier")].enumerated().compactMap { index, title in
            guard let rows = grouped[index], !rows.isEmpty else { return nil }
            return (title, rows)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    ScreenHeader(Text("Pick up the thread."),
                                 subtitle: Text(verbatim: "\(model.agent?.title ?? "Hermes") · \(String(localized: "\(conversations.count) conversations"))"),
                                 style: .title) {
                        AgentAvatar(name: model.profile, size: 42)
                    }.padding(.top, DS.Space.s)
                    if !model.demo && model.state != .connected {
                        ConnectionIndicator(model: model)
                    }
                    if let loadError, model.state == .connected {
                        InlineMessage(loadError, actionTitle: "Try again") { Task { await refresh() } }.disabled(loading)
                    }
                    if (loading || (!model.demo && model.state == .connecting)) && conversations.isEmpty {
                        ProgressView("Loading conversations…").frame(maxWidth: .infinity).padding(.vertical, DS.Space.xxxl)
                    } else if conversations.isEmpty {
                        ContentUnavailableView("It all starts here", systemImage: "bubble.left.and.bubble.right",
                            description: Text("Your conversations with this agent will appear here. One idea is enough to begin."))
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        ForEach(sections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: DS.Space.xs) {
                                SectionLabel(Text(section.title))
                                LazyVStack(spacing: DS.Space.xs) {
                                    ForEach(section.rows) { session in conversationRow(session) }
                                }
                            }
                        }
                    }
                }.padding(.horizontal, DS.Space.screen).padding(.bottom, DS.Space.xl).readableWidth()
            }.scrollDismissesKeyboard(.interactively)
                .background(DS.Palette.background)
                .navigationTitle("Conversations").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom, spacing: 0) { controls }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").icon(.s, weight: .semibold).frame(width: DS.Size.tap, height: DS.Size.tap)
                        }.foregroundStyle(DS.Palette.textPrimary).accessibilityLabel("Close conversations").accessibilityIdentifier("return-to-chat")
                    }
                }
                .task(id: "\(model.activeConnection?.id.uuidString ?? "demo")|\(model.profile)|\(model.state == .connected)") {
                    refreshID = UUID(); loading = false; loadError = nil
                    if model.demo || model.state == .connected { await refresh() }
                }
                .onChange(of: model.historyRevision) { _, _ in loadError = nil }
        }
    }

    private func conversationRow(_ session: Conversation) -> some View {
        let current = model.selected?.storedID == session.id && model.selected?.profile == session.profile
        return Button {
            guard openingID == nil else { return }
            searching = false
            if current { dismiss(); return }
            openingID = session.id
            Task {
                await model.openConversation(session)
                openingID = nil
                if model.selected?.storedID == session.id { dismiss() }
            }
        } label: {
            HStack(spacing: DS.Space.s) {
                IconTile(symbol: current ? "bubble.left.and.bubble.right.fill" : "bubble.left",
                         tint: current ? DS.Palette.accent : DS.Palette.textSecondary, size: 32, filled: current)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(session.title).textStyle(.label)
                        .foregroundStyle(DS.Palette.textPrimary).lineLimit(1).truncationMode(.tail)
                    if !session.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(session.preview.replacingOccurrences(of: "\n", with: " "))
                            .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).lineLimit(1).truncationMode(.tail)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: DS.Space.xs - 2) {
                    Text(session.updated, format: Calendar.current.isDateInToday(session.updated) ? .dateTime.hour().minute() : .dateTime.day().month(.abbreviated))
                        .textStyle(.footnote).foregroundStyle(DS.Palette.textTertiary).fixedSize()
                    if openingID == session.id { ProgressView().controlSize(.mini) }
                    else if current { Text("Current").textStyle(.footnote).fontWeight(.medium).foregroundStyle(DS.Palette.accentText).fixedSize() }
                    else { Image(systemName: "chevron.right").icon(.xs, weight: .medium).foregroundStyle(DS.Palette.textTertiary) }
                }
            }.padding(.horizontal, DS.Space.s + 2).padding(.vertical, DS.Space.s).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .tile(selected: current)
        }.buttonStyle(PressableStyle()).disabled(openingID != nil || model.sending || model.voiceActive)
            .accessibilityIdentifier("conversation-" + session.id)
            .accessibilityAddTraits(current ? .isSelected : [])
    }

    private var controls: some View {
        HStack(spacing: DS.Space.xs + 2) {
            if let navigation {
                IconButton("circle.grid.2x2", label: "Tools", style: .subtle, weight: .regular) { searching = false; navigation.showSpaces() }
                    .accessibilityIdentifier("back-to-spaces")
            }
            SearchField("Search", text: $search, focus: $searching, identifier: "history-search", label: "Search conversations")
                .submitLabel(.search).onSubmit { searching = false }
            IconButton("square.and.pencil", label: "New conversation", style: .accent, scale: .medium) { model.newChat(); dismiss() }
                .disabled(model.sending || model.voiceActive)
        }.padding(.horizontal, DS.Space.m).padding(.vertical, DS.Space.s).readableWidth(DS.Size.chatWidth)
            .background(DS.Palette.background)
    }

    private func refresh() async {
        guard !loading, model.demo || model.state == .connected else { return }
        let attempt = UUID(); refreshID = attempt
        let revision = model.historyRevision
        loading = true; loadError = nil
        defer { if refreshID == attempt { loading = false } }
        do { try await model.refreshSessions() }
        catch is CancellationError { }
        catch {
            guard refreshID == attempt, model.state == .connected, revision == model.historyRevision else { return }
            let reason = String(error.localizedDescription.prefix(240))
            if let rpc = error as? RPCFailure, rpc.code > 0 || rpc.code == -32601 {
                loadError = "\(reason) (Hermes \(rpc.code))"
            } else { loadError = reason }
        }
    }
}

struct BotEditor: View {
    let model: AppModel
    var bot: AgentProfile?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var detail = ""
    @State private var soul = ""
    @State private var clone = "default"
    @State private var busy = false
    @State private var loaded = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Profile name (e.g. researcher)", text: $name).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(bot != nil)
                    TextField("Its role, in a few words", text: $detail, axis: .vertical).lineLimit(2...4)
                } header: { Text("Identity") } footer: { Text("This profile will be available in all your Hermes interfaces.") }
                if bot == nil {
                    Section("Starting point") {
                        Picker("Configuration", selection: $clone) {
                            Text("New profile").tag("")
                            ForEach(model.profiles) { Text("Clone \($0.title)").tag($0.name) }
                        }
                    }
                }
                Section { TextEditor(text: $soul).frame(minHeight: 150) } header: { Text("Personality · SOUL.md") } footer: { Text("How it thinks, its tone and its standing instructions.") }
                if let error { Section { Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(DS.Palette.critical) } }
            }.modernList()
                .navigationTitle(bot == nil ? String(localized: "A new agent") : String(localized: "Edit \(bot!.title)")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(busy ? "Saving…" : "Save") { save() }.disabled(busy || name.isEmpty || (bot != nil && !loaded) || model.demo)
                    }
                }
                .task {
                    if let bot {
                        name = bot.name; detail = bot.detail
                        do { let data = try await model.describeBot(bot.name); soul = data["soul"].string; loaded = true }
                        catch { self.error = error.localizedDescription }
                    } else { loaded = true }
                }
        }
    }
    private func save() {
        busy = true; error = nil
        Task {
            do {
                if bot == nil { try await model.createBot(name: name, description: detail, soul: soul, clone: clone) }
                else { try await model.editBot(name: name, description: detail, soul: soul) }
                dismiss()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
