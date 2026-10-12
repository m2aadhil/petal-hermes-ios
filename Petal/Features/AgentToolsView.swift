import SwiftUI

struct ToolFeedback: View {
    let tools: NativeToolSession
    var body: some View {
        if tools.loading && tools.data.isNull {
            HStack(spacing: DS.Space.xs) { ProgressView(); Text("Opening…").textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary) }
        }
        if let error = tools.error {
            InlineMessage(error)
        }
    }
}

struct SkillsView: View {
    @State private var tools: NativeToolSession
    @State private var search = ""
    init(app: AppModel) { _tools = State(initialValue: NativeToolSession(app)) }
    private var skills: [JSONValue] {
        tools.data.array.filter { search.isEmpty || "\($0["name"].string) \($0["description"].string)".localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List { Group {
                Section { Text("Skills for \(tools.profile). Turn on the ones your agent needs.").foregroundStyle(DS.Palette.textSecondary) }
                ToolFeedback(tools: tools)
                ForEach(skills, id: \.["name"].string) { skill in
                    NavigationLink {
                        SkillDetailView(tools: tools, skill: skill)
                    } label: {
                        HStack(spacing: DS.Space.s) {
                            IconTile(symbol: "sparkles", size: 32)
                            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                Text(skill["name"].string).textStyle(.headline)
                                Text(skill["description"].string).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).lineLimit(2)
                            }
                            Spacer(minLength: DS.Space.xxs)
                            Circle().fill(skill["enabled"] == false ? DS.Palette.disabledFill : DS.Palette.success).frame(width: 7, height: 7)
                                .accessibilityLabel(skill["enabled"] == false ? "Off" : "On")
                        }.padding(.vertical, DS.Space.xs)
                    }
                }
                if !tools.data.isNull && skills.isEmpty { ContentUnavailableView("No skills", systemImage: "sparkles", description: Text("Your installed skills will appear here.")) }
            }.listRowBackground(Color.clear)
}.searchable(text: $search, prompt: "Search skills")
                .modernList()
                .navigationTitle("Skills").navigationBarTitleDisplayMode(.inline)
                .refreshable { await load() }.task { await load() }
        }
    }
    private func load() async { await tools.load("/api/skills") }
}

private struct SkillDetailView: View {
    let tools: NativeToolSession
    let skill: JSONValue
    @State private var content = ""
    @State private var enabled = true
    @State private var reading = true
    var body: some View {
        List { Group {
            Section {
                Text(skill["description"].string).foregroundStyle(DS.Palette.textSecondary)
                Toggle("Available to the agent", isOn: Binding(get: { enabled }, set: { value in
                    Task { await tools.perform {
                        let result = try await tools.request("/api/skills/toggle", method: "PUT", body: ["name": skill["name"], "enabled": .bool(value)])
                        guard result["ok"].bool else { throw RPCFailure(String(localized: "The skill wasn’t changed.")) }
                        enabled = result["enabled"].bool
                        await tools.load("/api/skills")
                    } }
                })).disabled(tools.busy || tools.app.demo)
            }
            ToolFeedback(tools: tools)
            Section("Instructions") {
                if reading { ProgressView() }
                else { Text(content.isEmpty ? String(localized: "No instructions available.") : content).textStyle(.code).textSelection(.enabled) }
            }
        }.listRowBackground(Color.clear)
}.modernList()
            .navigationTitle(skill["name"].string).navigationBarTitleDisplayMode(.inline)
            .task {
                enabled = skill["enabled"] != false
                defer { reading = false }
                if tools.app.demo { content = "# \(skill["name"].string)\n\n\(skill["description"].string)"; return }
                await tools.perform {
                    let result = try await tools.request("/api/skills/content", query: [URLQueryItem(name: "name", value: skill["name"].string)])
                    content = result["content"].string
                }
            }
    }
}

struct ModelsView: View {
    @State private var tools: NativeToolSession
    @State private var search = ""
    @State private var selection: JSONValue?
    @State private var confirmation: String?
    @State private var saved = false
    init(app: AppModel) { _tools = State(initialValue: NativeToolSession(app)) }
    var body: some View {
        NavigationStack {
            List { Group {
                Section {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Label(tools.data["model"].string.isEmpty ? String(localized: "Agent model") : tools.data["model"].string, systemImage: "cpu").textStyle(.headline)
                        Text("This applies to new sessions for \(tools.profile). The current conversation keeps its model.").textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary)
                    }.padding(.vertical, DS.Space.xs)
                }
                ToolFeedback(tools: tools)
                if saved { InlineMessage(String(localized: "Model saved"), kind: .success) }
                ForEach(tools.data["providers"].array, id: \.["slug"].string) { provider in
                    let models = provider["models"].array.map(\.string).filter { !$0.isEmpty && (search.isEmpty || $0.localizedCaseInsensitiveContains(search)) }
                    if !models.isEmpty {
                        Section(provider["name"].string) {
                            ForEach(models, id: \.self) { name in
                                Button {
                                    selection = ["scope": "main", "provider": provider["slug"], "model": .string(name), "base_url": provider["base_url"].isNull ? "" : provider["base_url"]]
                                } label: {
                                    HStack {
                                        Text(name).foregroundStyle(DS.Palette.textPrimary)
                                        Spacer()
                                        if name == tools.data["model"].string && provider["slug"] == tools.data["provider"] { Image(systemName: "checkmark").foregroundStyle(DS.Palette.accent) }
                                    }.padding(.vertical, DS.Space.xs)
                                }.disabled(tools.busy || tools.app.demo)
                            }
                        }
                    }
                }
                if !tools.data.isNull && tools.data["providers"].array.isEmpty {
                    ContentUnavailableView("No providers configured", systemImage: "cpu", description: Text("Set up a provider in Hermes to see its models here."))
                }
            }.listRowBackground(Color.clear)
}.searchable(text: $search, prompt: "Search models")
                .modernList()
                .navigationTitle("Models").navigationBarTitleDisplayMode(.inline)
                .task { await load() }.refreshable { await load() }
                .confirmationDialog("Use this model for new sessions?", isPresented: Binding(get: { selection != nil && confirmation == nil }, set: { if !$0 { selection = nil } }), titleVisibility: .visible) {
                    if let selection {
                        Button(selection["model"].string) { Task { await save(selection) } }
                    }
                    Button("Cancel", role: .cancel) { selection = nil }
                }
                .alert("Hermes confirmation", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil; selection = nil } })) {
                    Button("Confirm") {
                        if var body = selection?.object {
                            body["confirm_expensive_model"] = true
                            Task { await save(.object(body)) }
                        }
                    }
                    Button("Cancel", role: .cancel) { selection = nil; confirmation = nil }
                } message: { Text(confirmation ?? "") }
        }
    }
    private func load() async { await tools.load("/api/model/options") }
    private func save(_ body: JSONValue) async {
        await tools.perform {
            let result = try await tools.request("/api/model/set", method: "POST", body: body)
            if result["confirm_required"].bool {
                selection = body; confirmation = result["confirm_message"].string; return
            }
            guard result["ok"].bool else { throw RPCFailure(String(localized: "Hermes didn’t confirm the model change.")) }
            selection = nil; confirmation = nil; saved = true
            await load()
        }
    }
}

struct WorkspaceView: View {
    @State private var tools: NativeToolSession
    @State private var search = ""
    init(app: AppModel) { _tools = State(initialValue: NativeToolSession(app)) }
    var body: some View {
        NavigationStack {
            List { Group {
                Section { Text("Projects and folders for \(tools.profile), on your Hermes server.").foregroundStyle(DS.Palette.textSecondary) }
                ToolFeedback(tools: tools)
                ForEach(tools.data["projects"].array.filter { !$0["archived"].bool && $0["archived"].int == 0 && (search.isEmpty || $0["name"].string.localizedCaseInsensitiveContains(search)) }, id: \.["id"].string) { project in
                    NavigationLink {
                        List { Group {
                            if !project["description"].string.isEmpty { Text(project["description"].string) }
                            Section("Main folder") { Text(project["primary_path"].string).textStyle(.code).textSelection(.enabled) }
                            Section("Project folders") {
                                ForEach(project["folders"].array, id: \.["path"].string) { folder in
                                    VStack(alignment: .leading, spacing: DS.Space.xxs + 2) {
                                        if !folder["label"].string.isEmpty { Label(folder["label"].string, systemImage: "folder") }
                                        Text(folder["path"].string).textStyle(.codeSmall).foregroundStyle(DS.Palette.textSecondary).textSelection(.enabled)
                                    }
                                }
                            }
                            if !project["board_slug"].string.isEmpty { Section("Linked board") { Text(project["board_slug"].string) } }
                        }.listRowBackground(Color.clear)
}.navigationTitle(project["name"].string).navigationBarTitleDisplayMode(.inline)
                            .modernList()
                    } label: {
                        HStack(spacing: DS.Space.s) {
                            IconTile(symbol: "folder")
                            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                Text(project["name"].string).textStyle(.headline)
                                Text(project["primary_path"].string).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).lineLimit(1)
                            }
                        }.padding(.vertical, DS.Space.xs)
                    }
                }
                if !tools.data.isNull && tools.data["projects"].array.isEmpty { ContentUnavailableView("Your next project", systemImage: "folder", description: Text("Workspaces created in Hermes will appear here.")) }
            }.listRowBackground(Color.clear)
}.searchable(text: $search, prompt: "Find a project")
                .modernList()
                .navigationTitle("Workspace").navigationBarTitleDisplayMode(.inline)
                .task { await load() }.refreshable { await load() }
        }
    }
    private func load() async { await tools.load("projects.list", rpc: true) }
}
