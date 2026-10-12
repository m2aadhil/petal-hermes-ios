import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel
    var adding = false
    var existing: SavedConnection?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var address = ""
    @State private var name = String(localized: "My Hermes")
    @State private var username = ""
    @State private var password = ""
    @State private var token = ""
    @State private var mode = "basic"
    @State private var staySignedIn = true
    @State private var busy = false
    @State private var error: String?
    @State private var showGuide = false
    /// A signed-in connection waiting for the user to pick an agent (step 2).
    @State private var pending: PendingConnection?
    @State private var chosenProfile: String?

    private struct PendingConnection {
        let connection: SavedConnection
        let profiles: [AgentProfile]
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.xxl) {
                        HStack {
                            Wordmark()
                            Spacer()
                            Text(step == 0 ? "WELCOME" : step == 1 ? "CONNECT" : "YOUR AGENT").textStyle(.overline).foregroundStyle(DS.Palette.textSecondary)
                        }.padding(.top, DS.Space.s)
                        if step == 0 && !adding {
                            Spacer(minLength: DS.Space.l)
                            hero
                            VStack(alignment: .leading, spacing: DS.Space.s) {
                                Text("Your agent.\nSimply.").textStyle(.hero).fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                                Text("A calm place to talk with Hermes.\nYour ideas, your agents, your pace.")
                                    .textStyle(.body).foregroundStyle(DS.Palette.textSecondary)
                            }
                            HStack(spacing: DS.Space.l) {
                                Label("100% native", systemImage: "iphone")
                                Label("Self-hosted", systemImage: "lock.shield")
                            }.textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                            Spacer(minLength: DS.Space.s)
                            VStack(spacing: DS.Space.xs) {
                                PrimaryButton(title: "Meet my Hermes") {
                                    withAnimation(DS.Motion.adaptive(DS.Motion.standard, reduceMotion: reduceMotion)) { step = 1 }
                                }
                                Button("Explore the interface") { model.loadDemo() }
                                    .buttonStyle(HermesButtonStyle(kind: .quiet)).padding(.bottom, DS.Space.xs)
                            }
                        } else if step == 2, let pending {
                            profileChooser(pending)
                        } else {
                            ScreenHeader(Text("Let’s connect."), subtitle: Text("Open Tailscale on your iPhone, then enter your Hermes server’s address."))
                                .padding(.top, DS.Space.l)
                            VStack(alignment: .leading, spacing: DS.Space.l) {
                                field("Connection name", text: $name, placeholder: "My Hermes")
                                field("Hermes address", text: $address, placeholder: "https://hermes.tailnet.ts.net", url: true)
                                Picker("Authentication", selection: $mode) {
                                    Text("Hermes credentials").tag("basic")
                                    Text("Existing token").tag("token")
                                }.pickerStyle(.segmented)
                                if mode == "basic" {
                                    field("Username", text: $username, placeholder: "admin")
                                    FormField(label: "Password") {
                                        SecureField("Hermes password", text: $password).textContentType(.password)
                                    }
                                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                        Toggle("Stay signed in", isOn: $staySignedIn).textStyle(.label)
                                            .accessibilityIdentifier("stay-signed-in")
                                        Text("Saves your password in this iPhone’s Keychain so Petal can sign in again when the session expires.")
                                            .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                                    }
                                } else {
                                    FormField(label: "Server session token") {
                                        SecureField("Server session token", text: $token)
                                    }
                                    Text("The Hermes session token, not a model provider key.").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                                }
                            }.card()
                            if let error { InlineMessage(error) }
                            PrimaryButton(title: "Connect my agent", symbol: "link", busy: busy) { connect() }
                                .disabled(address.isEmpty || (mode == "basic" ? password.isEmpty || username.isEmpty : token.isEmpty))
                                .accessibilityIdentifier("connect-agent")
                            Button { showGuide = true } label: {
                                Label("Where do I find this?", systemImage: "questionmark.circle")
                            }.buttonStyle(HermesButtonStyle(kind: .quiet))
                            Label("Direct connection to Hermes. Your credentials stay in this iPhone’s Keychain.", systemImage: "lock")
                                .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                            Spacer(minLength: DS.Space.s)
                        }
                    }.padding(.horizontal, DS.Space.xxl).frame(maxWidth: DS.Size.formWidth).frame(minHeight: geo.size.height).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively).background(DS.Palette.background)
            }
            .toolbar {
                if adding { ToolbarItem(placement: .cancellationAction) { Button("Close") { abandonPending(); dismiss() } } }
                if step == 2 || (step == 1 && !adding) {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { goBack() } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Back")
                    }
                }
            }
            .sheet(isPresented: $showGuide) { ConnectionGuide() }
            .onDisappear { abandonPending() }
            .onAppear {
                if adding { step = 1 }
                if let existing { name = existing.name; address = existing.endpoint.baseURL.absoluteString; mode = existing.mode }
            }
        }
    }

    private var hero: some View {
        ZStack {
            Circle().fill(DS.Palette.accent.opacity(0.045)).frame(width: 246, height: 246)
            Circle().strokeBorder(DS.Palette.accent.opacity(0.13), lineWidth: 1).frame(width: 205, height: 205)
            Circle().strokeBorder(DS.Palette.accent.opacity(0.07), lineWidth: 1).frame(width: 274, height: 274)
            AgentMark(size: 116)
            Text("you").textStyle(.captionEmphasis).padding(.horizontal, DS.Space.m).padding(.vertical, DS.Space.xs)
                .background(DS.Palette.surface, in: Capsule()).elevation(.floating).rotationEffect(.degrees(-8)).offset(x: -95, y: 62)
            HStack(spacing: DS.Space.xxs) { StatusDot(color: DS.Palette.success, size: 5); Text(verbatim: "Hermes") }.textStyle(.captionEmphasis)
                .padding(.horizontal, DS.Space.m).padding(.vertical, DS.Space.xs + 2).background(DS.Palette.surface, in: Capsule())
                .elevation(.floating).rotationEffect(.degrees(7)).offset(x: 93, y: -61)
        }.frame(maxWidth: .infinity).frame(height: 260).accessibilityHidden(true)
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey, url: Bool = false) -> some View {
        FormField(label: label) {
            TextField(placeholder, text: text).textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(url ? .URL : .default).accessibilityLabel(label)
        }
    }

    private func profileChooser(_ pending: PendingConnection) -> some View {
        let chosenTitle = pending.profiles.first { $0.name == chosenProfile }?.title ?? "Hermes"
        return VStack(alignment: .leading, spacing: DS.Space.l) {
            ScreenHeader(Text("Who would you like to talk to?"),
                         subtitle: Text("Choose the agent to start with. You can switch any time from the chat."))
                .padding(.top, DS.Space.l)
            Label(pending.connection.name, systemImage: "server.rack")
                .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
            VStack(spacing: DS.Space.xs) {
                ForEach(pending.profiles) { agent in
                    let chosen = chosenProfile == agent.name
                    Button { chosenProfile = agent.name } label: {
                        HStack(spacing: DS.Space.s) {
                            AgentAvatar(name: agent.name, size: 44)
                            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                Text(agent.title).textStyle(.bodyEmphasis).foregroundStyle(DS.Palette.textPrimary)
                                Text(agent.detail.isEmpty ? (agent.model.isEmpty ? "@\(agent.name)" : agent.model) : agent.detail)
                                    .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                                .icon(.l).foregroundStyle(chosen ? DS.Palette.accent : DS.Palette.textTertiary)
                                .accessibilityHidden(true)
                        }.padding(DS.Space.m).tile(selected: chosen)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("choose-profile-\(agent.name)")
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            if let error { InlineMessage(error) }
            PrimaryButton(title: "Start with \(chosenTitle)", busy: busy) { finish() }
                .disabled(chosenProfile == nil)
                .accessibilityIdentifier("start-with-agent")
            Spacer(minLength: DS.Space.s)
        }
    }

    private func connect() {
        busy = true; error = nil
        Task {
            do {
                let endpoint = try Endpoint(address)
                let connection = SavedConnection(id: existing?.id ?? UUID(), name: name.isEmpty ? "Hermes" : name, endpoint: endpoint, mode: mode)
                let found = try await model.verifyConnection(connection, username: username, password: password, token: token, remember: mode == "basic" && staySignedIn)
                password = ""; token = ""
                if found.count > 1 {
                    pending = PendingConnection(connection: connection, profiles: found)
                    chosenProfile = initialChoice(in: found)
                    withAnimation(DS.Motion.adaptive(DS.Motion.standard, reduceMotion: reduceMotion)) { step = 2 }
                } else {
                    try await model.finishConnection(connection, profiles: found, startWith: found.first?.name)
                    dismiss()
                }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    /// Reconnecting keeps the agent that was active; a new server starts on its default profile.
    private func initialChoice(in found: [AgentProfile]) -> String? {
        if let existing, model.activeConnection?.id == existing.id, found.contains(where: { $0.name == model.profile }) {
            return model.profile
        }
        return found.first(where: { $0.name == "default" })?.name ?? found.first?.name
    }

    private func finish() {
        guard let pending else { return }
        busy = true; error = nil
        Task {
            do {
                try await model.finishConnection(pending.connection, profiles: pending.profiles, startWith: chosenProfile)
                self.pending = nil
                dismiss()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    private func goBack() {
        withAnimation(DS.Motion.adaptive(DS.Motion.standard, reduceMotion: reduceMotion)) {
            if step == 2 { abandonPending(); step = 1 } else { step = 0 }
        }
    }

    /// Forget credentials from a sign-in the user didn't finish.
    private func abandonPending() {
        guard let pending else { return }
        model.discardPendingConnection(pending.connection)
        self.pending = nil; chosenProfile = nil; error = nil
    }
}

struct ConnectionGuide: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    Text("Your Hermes,\nin your pocket.").textStyle(.display).accessibilityAddTraits(.isHeader)
                    instruction("1", "The same private network", "Connect your server and your iPhone to the same Tailscale account. Keep Tailscale on while using the iPhone.")
                    instruction("2", "Hermes’ native access", "On your server, set the Hermes dashboard credentials in its .env file, along with a stable signing secret.")
                    Text(verbatim: "HERMES_DASHBOARD_BASIC_AUTH_USERNAME\nHERMES_DASHBOARD_BASIC_AUTH_PASSWORD\nHERMES_DASHBOARD_BASIC_AUTH_SECRET")
                        .textStyle(.codeSmall).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).card(padding: DS.Space.m)
                    instruction("3", "Start the server", "Run the official server on its private Tailscale address. Petal talks to its API directly.")
                    Text(verbatim: "hermes serve --host <Tailscale-IP> --port 9119")
                        .textStyle(.codeSmall).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).card(padding: DS.Space.m)
                    Text("In Petal, enter http://<Tailscale-IP>:9119. If you use Tailscale Serve with HTTPS, enter its https://…ts.net address instead.")
                        .textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary)
                    Link("Open the official documentation", destination: URL(string: "https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend")!)
                    Text("Password authentication is meant for your private network. Petal doesn’t configure your server for you.")
                        .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                }.padding(DS.Space.xl).readableWidth(DS.Size.formWidth)
            }.background(DS.Palette.background).navigationTitle("Connection").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func instruction(_ n: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: DS.Space.s + 2) {
            Text(verbatim: n).textStyle(.label).frame(width: 30, height: 30).background(DS.Palette.accentSoft, in: Circle()).foregroundStyle(DS.Palette.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.xxs + 2) {
                Text(title).textStyle(.headline)
                Text(detail).textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary)
            }
        }.accessibilityElement(children: .combine)
    }
}
