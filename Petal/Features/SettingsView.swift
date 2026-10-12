import SwiftUI

struct SettingsView: View {
    @AppStorage(ThinkingPreference.showKey) private var showThinking = true
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var reconnecting: SavedConnection?
    @State private var removing: SavedConnection?
    @State private var guide = false
    var body: some View {
        NavigationStack {
            List { Group {
                Section {
                    HStack(spacing: DS.Space.m) {
                        AgentMark(size: 48)
                        VStack(alignment: .leading, spacing: DS.Space.xxs) {
                            Text(verbatim: "Petal").textStyle(.wordmark).accessibilityAddTraits(.isHeader)
                            Text("Less noise. More conversation.").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                        }
                    }.padding(.vertical, DS.Space.s)
                }.listRowBackground(Color.clear)
                Section("Your connections") {
                    ForEach(model.connections) { connection in
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Button { Task { await model.activate(connection) } } label: {
                                HStack(spacing: DS.Space.s) {
                                    IconTile(symbol: "server.rack", size: 32)
                                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                        Text(connection.name).foregroundStyle(DS.Palette.textPrimary)
                                        Text(connection.endpoint.baseURL.host ?? "").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                                    }
                                    Spacer()
                                    if model.activeConnection?.id == connection.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Palette.accent)
                                    }
                                }
                            }
                            HStack {
                                Button("Reconnect") { reconnecting = connection }.textStyle(.caption)
                                Spacer()
                                Button("Remove", role: .destructive) { removing = connection }.textStyle(.caption)
                            }.buttonStyle(.borderless)
                        }.padding(.vertical, DS.Space.xxs)
                    }
                    Button { adding = true } label: { Label("Connect a Hermes server", systemImage: "plus") }
                }
                Section {
                    // iOS offers a per-app language picker in Settings once the app ships more than one localization.
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Text(verbatim: Locale.current.localizedString(forLanguageCode: Bundle.main.preferredLocalizations.first ?? "en")?.localizedCapitalized ?? "")
                                .foregroundStyle(DS.Palette.textSecondary)
                        }
                    }.foregroundStyle(DS.Palette.textPrimary).accessibilityIdentifier("language-settings")
                    Toggle(isOn: $showThinking) { Label("Show thinking", systemImage: "sparkle") }
                        .tint(DS.Palette.accent).accessibilityIdentifier("show-thinking")
                } header: { Text("Preferences") } footer: {
                    Text("Language opens iOS Settings. Show thinking displays the model’s reasoning above replies when your model shares it; it only affects this iPhone.")
                }
                Section("Simple by nature") {
                    Label("Native SwiftUI interface", systemImage: "iphone")
                    Label("Direct connection to your server", systemImage: "point.3.connected.trianglepath.dotted")
                    Label("No Petal account, no telemetry", systemImage: "hand.raised")
                }.textStyle(.subheadline)
                Section {
                    Button { guide = true } label: { Label("Tailscale & Hermes guide", systemImage: "book") }
                    Link(destination: URL(string: "https://github.com/Molliex05/hermes-ios")!) { Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right") }
                    Link(destination: URL(string: "https://hermes-agent.nousresearch.com/docs/")!) { Label("Hermes documentation", systemImage: "arrow.up.right.square") }
                    HStack { Text("Version"); Spacer(); Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").foregroundStyle(DS.Palette.textSecondary) }
                } footer: {
                    Text("Petal is an independent community client for Hermes Agent by Nous Research. Conversations are cached on this device. Removing a connection clears its local cache without touching the server.")
                }
                if model.demo {
                    Section { Button("Exit preview") { model.demo = false; model.selected = nil; model.profiles = []; model.transcript = Transcript() } }
                }
            }.listRowBackground(Color.clear)
}.modernList()
                .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.accessibilityIdentifier("close-settings")
                    }
                }
                .sheet(isPresented: $adding) { OnboardingView(model: model, adding: true) }
                .sheet(item: $reconnecting) { OnboardingView(model: model, adding: true, existing: $0) }
                .sheet(isPresented: $guide) { ConnectionGuide() }
                .confirmationDialog("Remove this connection and its cache from this iPhone?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                    Button("Remove from this iPhone", role: .destructive) {
                        if let connection = removing { Task { await model.removeConnection(connection) } }
                        removing = nil
                    }
                }
        }
    }
}
