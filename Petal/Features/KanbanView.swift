import SwiftUI

struct KanbanView: View {
    @State private var boards: NativeToolSession
    @State private var board: NativeToolSession
    @State private var slug = ""
    @State private var filter = "all"
    @State private var creating = false
    @State private var detail: JSONValue?
    @State private var creationID = UUID().uuidString
    @State private var title = ""
    @State private var bodyText = ""
    @Environment(\.scenePhase) private var scenePhase
    init(app: AppModel) {
        _boards = State(initialValue: NativeToolSession(app)); _board = State(initialValue: NativeToolSession(app))
    }
    private var query: [URLQueryItem] { [URLQueryItem(name: "board", value: slug)] }
    private var columns: [JSONValue] { board.data["columns"].array }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    HStack(alignment: .center) {
                        Menu {
                            ForEach(boards.data["boards"].array, id: \.["slug"].string) { row in
                                Button(row["name"].string.isEmpty ? row["slug"].string : row["name"].string) { slug = row["slug"].string }
                            }
                        } label: {
                            HStack(spacing: DS.Space.xs) {
                                Text(boards.data["boards"].array.first(where: { $0["slug"].string == slug })?["name"].string ?? String(localized: "Boards"))
                                    .textStyle(.title).accessibilityAddTraits(.isHeader)
                                Image(systemName: "chevron.down").icon(.xs, weight: .semibold).foregroundStyle(DS.Palette.textSecondary)
                            }.frame(minHeight: DS.Size.tap)
                        }.buttonStyle(.plain).disabled(boards.data.isNull).accessibilityLabel("Choose a board")
                        Spacer()
                        Text("\(columns.reduce(0) { $0 + $1["tasks"].array.count }) tasks")
                            .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                    }.padding(.top, DS.Space.xs)
                    ToolFeedback(tools: boards)
                    ToolFeedback(tools: board)
                    ForEach(columns.filter { (filter == "all" || $0["name"].string == filter) && !$0["tasks"].array.isEmpty }, id: \.["name"].string) { column in
                        VStack(alignment: .leading, spacing: DS.Space.s - 2) {
                            HStack(spacing: DS.Space.xs) {
                                StatusDot(color: statusColor(column["name"].string))
                                Text(statusName(column["name"].string)).textStyle(.overline)
                                Text(verbatim: "\(column["tasks"].array.count)").textStyle(.footnote).foregroundStyle(DS.Palette.textTertiary)
                                Spacer()
                            }.foregroundStyle(DS.Palette.textSecondary).padding(.horizontal, DS.Space.xxs)
                                .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
                            ForEach(column["tasks"].array, id: \.["id"].string) { task in
                                Button { detail = task } label: {
                                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                                        Text(task["title"].string).textStyle(.label).foregroundStyle(DS.Palette.textPrimary)
                                        if !task["body"].string.isEmpty { Text(task["body"].string).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).lineLimit(2) }
                                        if !task["assignee"].string.isEmpty {
                                            HStack(spacing: DS.Space.xxs + 2) {
                                                AgentAvatar(name: task["assignee"].string, size: 18)
                                                Text(task["assignee"].string).textStyle(.footnote).foregroundStyle(DS.Palette.textSecondary)
                                            }
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(DS.Space.m)
                                        .tile()
                                }.buttonStyle(PressableStyle())
                            }
                        }
                    }
                    if !board.data.isNull && columns.filter({ filter == "all" || $0["name"].string == filter }).allSatisfy({ $0["tasks"].array.isEmpty }) {
                        ContentUnavailableView("An idea to organize?", systemImage: "rectangle.split.3x1", description: Text("Add a task to find it on your Hermes board."))
                    }
                }.padding(.horizontal, DS.Space.screen).padding(.bottom, DS.Space.xl).readableWidth()
            }.background(DS.Palette.background)
                .navigationTitle("Kanban").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ToolDock {
                        Menu {
                            Button("Show all") { filter = "all" }
                            ForEach(columns, id: \.["name"].string) { column in
                                Button(statusName(column["name"].string)) { filter = column["name"].string }
                            }
                        } label: { Image(systemName: "line.3.horizontal.decrease").icon(.m).frame(width: DS.Size.tap, height: DS.Size.tap) }
                            .accessibilityLabel("Filter tasks")
                        Button { creating = true } label: { Image(systemName: "plus").icon(.m).frame(width: DS.Size.tap, height: DS.Size.tap) }
                            .disabled(slug.isEmpty || board.data.isNull || board.app.demo).accessibilityLabel("New task")
                    }
                }
                .refreshable { await refresh() }
                .task {
                    await boards.load("/api/plugins/kanban/boards")
                    if slug.isEmpty { slug = boards.data["current"].string.isEmpty ? boards.data["boards"].array.first?["slug"].string ?? "" : boards.data["current"].string }
                }
                .task(id: "\(slug)-\(scenePhase == .active)") {
                    guard !slug.isEmpty, scenePhase == .active else { return }
                    // Same visible-only fallback cadence as the native desktop board.
                    while !Task.isCancelled {
                        await refresh()
                        do { try await Task.sleep(for: .seconds(8)) } catch { return }
                    }
                }
                .onChange(of: slug) { _, _ in filter = "all" }
                .sheet(isPresented: $creating) { createForm }
                .sheet(isPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })) {
                    if let detail { KanbanDetailView(tools: board, task: detail, board: slug) }
                }
        }
    }
    private func refresh() async { if !slug.isEmpty { await board.load("/api/plugins/kanban/board", query: query) } }
    private var createForm: some View {
        NavigationStack {
            Form {
                TextField("Task title", text: $title).disabled(board.busy)
                    .onChange(of: title) { _, _ in if !board.busy { creationID = UUID().uuidString } }
                TextField("A few details…", text: $bodyText, axis: .vertical).lineLimit(4...10).disabled(board.busy)
                    .onChange(of: bodyText) { _, _ in if !board.busy { creationID = UUID().uuidString } }
                Text("Added to Triage. Hermes still handles orchestrating this idea.").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                ToolFeedback(tools: board)
            }.navigationTitle("New task").navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    Button { Task { await board.perform {
                        let result = try await board.request("/api/plugins/kanban/tasks", method: "POST", body: ["title": .string(title), "body": .string(bodyText), "triage": true, "idempotency_key": .string(creationID)], query: query)
                        guard !result["task"]["id"].string.isEmpty else { throw RPCFailure(String(localized: "Hermes didn’t confirm the task was created. Check the board before trying again.")) }
                        creating = false; title = ""; bodyText = ""; creationID = UUID().uuidString; await refresh()
                    } } } label: { Text(board.busy ? "Adding…" : "Add to board") }
                        .buttonStyle(HermesButtonStyle(kind: .primary)).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || board.busy).padding(DS.Space.l)
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { creating = false } } }
        }.interactiveDismissDisabled(board.busy)
    }
}

private struct KanbanDetailView: View {
    let tools: NativeToolSession
    let task: JSONValue
    let board: String
    @State private var full: JSONValue = .null
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(task["title"].string).textStyle(.title)
                    HStack(spacing: DS.Space.xs) {
                        StatusDot(color: statusColor(task["status"].string), size: 8)
                        Text(statusName(task["status"].string)).textStyle(.label).foregroundStyle(DS.Palette.textSecondary)
                    }.accessibilityElement(children: .combine)
                    Text(full["task"]["body"].isNull ? task["body"].string : full["task"]["body"].string).textSelection(.enabled)
                }
                ToolFeedback(tools: tools)
                if !full["task"]["result"].string.isEmpty { Section("Result") { Text(full["task"]["result"].string).textSelection(.enabled) } }
                if !full["comments"].array.isEmpty {
                    Section("Comments") {
                        ForEach(Array(full["comments"].array.enumerated()), id: \.offset) { _, comment in
                            VStack(alignment: .leading, spacing: DS.Space.xxs + 2) { Text(comment["author"].string).textStyle(.sectionLabel); Text(comment["body"].string).textStyle(.body) }
                        }
                    }
                }
            }.navigationTitle("Task").navigationBarTitleDisplayMode(.inline)
                .modernList()
                .safeAreaInset(edge: .bottom) { Button("Back to board") { dismiss() }.buttonStyle(HermesButtonStyle(kind: .secondary)).padding(DS.Space.m) }
                .task {
                    guard !tools.app.demo else { return }
                    await tools.perform {
                        full = try await tools.request("/api/plugins/kanban/tasks/\(task["id"].string)", query: [URLQueryItem(name: "board", value: board)])
                    }
                }
        }
    }
}

/// Semantic colour for a Kanban status.
private func statusColor(_ status: String) -> Color {
    switch status {
    case "done": DS.Palette.success
    case "running", "review": DS.Palette.accent
    case "blocked": DS.Palette.warning
    case "failed": DS.Palette.critical
    default: DS.Palette.disabledFill
    }
}

private func statusName(_ status: String) -> String {
    ["triage": String(localized: "Triage", comment: "Kanban status"), "todo": String(localized: "To do", comment: "Kanban status"), "ready": String(localized: "Ready", comment: "Kanban status"), "running": String(localized: "In progress", comment: "Kanban status"), "blocked": String(localized: "Blocked", comment: "Kanban status"), "review": String(localized: "In review", comment: "Kanban status"), "done": String(localized: "Done", comment: "Kanban status"), "failed": String(localized: "Failed", comment: "Kanban status"), "archived": String(localized: "Archived", comment: "Kanban status")][status] ?? status.capitalized
}
