import SwiftUI

struct RoutinesView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    var body: some View {
        NavigationStack {
            List { Group {
                Section {
                    Text("Routines for \(model.agent?.title ?? "Hermes") keep running on your server, even when Petal is closed.").textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary)
                }
                if model.routines.isEmpty {
                    ContentUnavailableView("A rhythm to invent", systemImage: "sun.max", description: Text("A morning briefing, a watchlist, a weekly review. Hand a habit to your agent."))
                }
                ForEach(model.routines) { routine in
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        HStack {
                            Text(routine.name).textStyle(.headline)
                            Spacer()
                            Button { Task { await model.toggleRoutine(routine) } } label: {
                                Image(systemName: routine.paused ? "play.circle" : "pause.circle").icon(.xl)
                                    .frame(minWidth: DS.Size.tap, minHeight: DS.Size.tap)
                            }.buttonStyle(.borderless).accessibilityLabel(routine.paused ? "Resume" : "Pause")
                        }
                        Text(routine.prompt).textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary).lineLimit(3)
                        Label(routine.paused ? String(localized: "Paused") : routine.schedule, systemImage: "clock").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                    }.padding(.vertical, DS.Space.xs)
                }
            }.listRowBackground(Color.clear)
}.modernList()
                .navigationTitle("Routines").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }

                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ToolDock { Button { creating = true } label: { Label("Add", systemImage: "plus").frame(minHeight: 44) }.disabled(model.demo).accessibilityLabel("New routine") }
                }.task { await model.loadRoutines() }
                .sheet(isPresented: $creating) { RoutineEditor(model: model) }
        }
    }
}

struct RoutineEditor: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var prompt = ""
    @State private var schedule = "0 8 * * *"
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("A small habit") {
                    TextField("Routine name", text: $name)
                    TextField("What should your agent do?", text: $prompt, axis: .vertical).lineLimit(4...8)
                }
                Section {
                    Picker("Schedule", selection: $schedule) {
                        Text("Every morning at 8 AM").tag("0 8 * * *")
                        Text("Weekdays at 9 AM").tag("0 9 * * 1-5")
                        Text("Fridays at 5 PM").tag("0 17 * * 5")
                        Text("Every hour").tag("0 * * * *")
                    }
                } footer: { Text("Hermes server time. The result arrives in this agent’s Bot Chat.") }
                if let error { Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(DS.Palette.critical) }
            }.modernList()
                .navigationTitle("New routine").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(busy ? "Creating…" : "Create") { create() }.disabled(name.isEmpty || prompt.isEmpty || busy) }
                }
        }
    }
    private func create() {
        busy = true
        Task {
            do { try await model.createRoutine(name: name, prompt: prompt, schedule: schedule); dismiss() }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
