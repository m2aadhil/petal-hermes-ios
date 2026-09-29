import SwiftUI
import Observation

private struct GroupCache: Codable, Sendable {
    var rooms: [JSONValue] = []
    var events: [String: [JSONValue]] = [:]
    var cursors: [String: Int] = [:]
    var drafts: [String: String] = [:]
    var pending: [String: JSONValue] = [:]
}

@MainActor @Observable
private final class GroupModel {
    let connectionID: UUID
    let app: AppModel
    var data = GroupCache()
    var supported = false
    var error: String?
    var busy = false
    @ObservationIgnored private let cache = LocalCache()
    init(app: AppModel, connectionID: UUID) { self.app = app; self.connectionID = connectionID }
    func boot() async {
        data = await cache.read(GroupCache.self, key: connectionID.uuidString + "-groups") ?? GroupCache()
        do {
            let capabilities = try await call("groups.capabilities")
            supported = capabilities["driver"].bool && capabilities["methods"].array.contains("groups.send")
            guard supported else { error = String(localized: "This server doesn’t expose native groups yet. Update Hermes and restart hermes serve."); return }
            try await refreshRooms()
        } catch { self.error = error.localizedDescription }
    }
    func call(_ method: String, _ params: JSONValue = [:]) async throws -> JSONValue {
        try await app.groupRequest(method, params: params, connectionID: connectionID)
    }
    func refreshRooms() async throws {
        var rows: [JSONValue] = []
        var offset = 0
        repeat {
            let result = try await call("groups.list", ["limit": 100, "offset": .number(Double(offset))])
            rows += result["rooms"].array
            if result["next_offset"].isNull { break }
            offset = result["next_offset"].int
        } while offset < 1000
        data.rooms = rows
        await save()
    }
    func create(name: String, members: [AgentProfile], id: String) async throws {
        _ = try await call("groups.create", ["room_id": .string(id), "name": .string(name), "members": .array(members.map {
            ["member_id": .string($0.name), "profile": .string($0.name), "handle": .string($0.name), "display_name": .string($0.title)]
        })])
        try await refreshRooms()
    }
    func refresh(_ room: String) async {
        do {
            var pages = 0
            repeat {
                let result = try await call("groups.log", ["room_id": .string(room), "since_seq": .number(Double(data.cursors[room] ?? 0)), "limit": 100])
                var known = Set((data.events[room] ?? []).map { $0["event_id"].string })
                let incoming = result["events"].array.filter { known.insert($0["event_id"].string).inserted }
                data.events[room, default: []].append(contentsOf: incoming)
                data.cursors[room] = result["cursor"].int
                pages += 1
                if !result["has_more"].bool { break }
            } while pages < 20
            await save()
        } catch { self.error = error.localizedDescription }
    }
    func send(_ room: String, text: String) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        // Unlike prompt.submit, the official groups API has durable idempotent event IDs.
        let pending = data.pending[room] ?? ["room_id": .string(room), "event_id": .string(UUID().uuidString), "payload": ["text": .string(text), "thread_id": .string(UUID().uuidString)]]
        data.pending[room] = pending
        await save()
        do {
            _ = try await call("groups.send", pending)
            data.pending.removeValue(forKey: room); data.drafts[room] = ""
            await refresh(room)
        } catch { self.error = String(localized: "Send pending. Retrying reuses the same ID and won’t create a duplicate. \(error.localizedDescription)") }
        await save()
    }
    func stop(_ room: String) async {
        do { _ = try await call("groups.stop", ["room_id": .string(room), "cancel_id": .string(UUID().uuidString)]) }
        catch { self.error = error.localizedDescription }
    }
    func save() async {
        guard app.connections.contains(where: { $0.id == connectionID }) else { return }
        do { try await cache.save(data, key: connectionID.uuidString + "-groups") }
        catch { self.error = String(localized: "The group cache couldn’t be saved.") }
    }
}

struct GroupsView: View {
    let app: AppModel
    let connectionID: UUID
    @State private var model: GroupModel?
    @State private var creating = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Many perspectives, one conversation. Hermes orchestrates the agents on your server.").textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary)
                }
                if let model {
                    ForEach(model.data.rooms, id: \.["room_id"].string) { room in
                        NavigationLink { GroupChatView(model: model, room: room) } label: {
                            HStack(spacing: DS.Space.s) {
                                IconTile(symbol: "person.2.bubble", size: 32)
                                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                    Text(room["name"].string)
                                    Text("\(room["members"].array.count) agents").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                                }
                            }.padding(.vertical, DS.Space.xs)
                        }
                    }
                    if model.data.rooms.isEmpty {
                        ContentUnavailableView("Cross-pollinate ideas", systemImage: "person.2", description: Text("Invite two to six agents from this server into a group."))
                    }
                    if let error = model.error { InlineMessage(error) }
                }
            }.scrollContentBackground(.hidden).background(DS.Palette.background).navigationTitle("Together")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) { Button { creating = true } label: { Image(systemName: "plus") }.disabled(model?.supported != true) }
                }
                .task { if model == nil { let m = GroupModel(app: app, connectionID: connectionID); model = m; await m.boot() } }
                .sheet(isPresented: $creating) { if let model { GroupEditor(model: model) } }
        }
    }
}

private struct GroupEditor: View {
    let model: GroupModel
    @State private var name = ""
    @State private var members = Set<String>()
    @State private var busy = false
    @State private var error: String?
    @State private var roomID = UUID().uuidString
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Group name", text: $name)
                Section("2 to 6 agents") {
                    ForEach(model.app.profiles) { agent in
                        Toggle(agent.title, isOn: Binding(get: { members.contains(agent.name) }, set: { enabled in
                            if enabled { members.insert(agent.name) } else { members.remove(agent.name) }
                        }))
                    }
                }
                if let error { Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(DS.Palette.critical) }
            }.navigationTitle("New group").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            busy = true
                            Task {
                                do { try await model.create(name: name, members: model.app.profiles.filter { members.contains($0.name) }, id: roomID); dismiss() }
                                catch { self.error = error.localizedDescription }
                                busy = false
                            }
                        }.disabled(busy || name.isEmpty || !(2...6).contains(members.count))
                    }
                }
        }
    }
}

private struct GroupChatView: View {
    @Bindable var model: GroupModel
    let room: JSONValue
    @Environment(\.scenePhase) private var phase
    private var id: String { room["room_id"].string }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Space.xl) {
                Text(room["members"].array.map { $0["display_name"].string.isEmpty ? $0["profile"].string : $0["display_name"].string }.joined(separator: " · "))
                    .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary).frame(maxWidth: .infinity)
                ForEach(model.data.events[id] ?? [], id: \.["event_id"].string) { event in
                    if ["message.user", "message.member"].contains(event["kind"].string) {
                        let member = room["members"].array.first { $0["member_id"] == event["actor"]["id"] }
                        MessageView(message: .init(id: event["event_id"].string, role: event["kind"].string == "message.user" ? "user" : "assistant", text: event["payload"]["text"].string), agent: member?["display_name"].string ?? event["actor"]["id"].string)
                    } else if event["kind"].string == "room.status" {
                        Text(event["payload"]["status"].string).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                    }
                }
                if let error = model.error { InlineMessage(error) }
            }.padding(DS.Space.screen).readableWidth(DS.Size.chatWidth)
        }.defaultScrollAnchor(.bottom).scrollDismissesKeyboard(.interactively).background(DS.Palette.background)
            .navigationTitle(room["name"].string).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { Task { await model.stop(id) } } label: { Image(systemName: "stop.circle") }.accessibilityLabel("Stop the agents") } }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: DS.Space.s) {
                    TextField("An idea to share…", text: Binding(get: { model.data.drafts[id] ?? "" }, set: { model.data.drafts[id] = $0 }), axis: .vertical).lineLimit(1...5).fieldStyle()
                    Button(model.data.pending[id] == nil ? "Send" : "Try again") {
                        Task { await model.send(id, text: model.data.drafts[id] ?? "") }
                    }.disabled(model.busy || ((model.data.drafts[id] ?? "").isEmpty && model.data.pending[id] == nil))
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(DS.Space.m).background(DS.Palette.surface).overlay(alignment: .top) { Divider() }
            }
            .task(id: phase) {
                guard phase == .active else { await model.save(); return }
                // Native hosted rooms expose cursor-based logs, not per-token WS notifications.
                // Pull deltas only while this room is visible; cached rows never disappear.
                while !Task.isCancelled {
                    await model.refresh(id)
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                }
            }
            .onDisappear { Task { await model.save() } }
    }
}
