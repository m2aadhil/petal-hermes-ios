import SwiftUI

/// One catalogue drives discovery and routing; adding a tool never adds another tab.
enum AppDestination: String, Identifiable, CaseIterable {
    case spaces, profiles, history, agents, groups, routines, kanban, workspace, skills, models, voice, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spaces: String(localized: "Tools")
        case .profiles: String(localized: "Profiles")
        case .history: String(localized: "Conversations")
        case .agents: String(localized: "Agents")
        case .groups: String(localized: "Groups")
        case .routines: String(localized: "Routines")
        case .kanban: String(localized: "Kanban")
        case .workspace: String(localized: "Workspace")
        case .skills: String(localized: "Skills")
        case .models: String(localized: "Models")
        case .voice: String(localized: "Voice")
        case .settings: String(localized: "Settings")
        }
    }
    var detail: String {
        switch self {
        case .spaces: String(localized: "All of your Hermes")
        case .profiles: String(localized: "Switch agent")
        case .history: String(localized: "Pick up the thread")
        case .agents: String(localized: "Profiles and Bot Mode")
        case .groups: String(localized: "Team up")
        case .routines: String(localized: "Schedule · cron jobs")
        case .kanban: String(localized: "Track tasks")
        case .workspace: String(localized: "Projects and folders")
        case .skills: String(localized: "Its skills")
        case .models: String(localized: "Choose its model")
        case .voice: String(localized: "Talk with your agent")
        case .settings: String(localized: "Connections and preferences")
        }
    }
    var symbol: String {
        switch self {
        case .spaces: "slider.horizontal.3"
        case .profiles: "person.crop.circle"
        case .history: "bubble.left.and.bubble.right"
        case .agents: "person.crop.circle"
        case .groups: "person.2"
        case .routines: "clock.arrow.2.circlepath"
        case .kanban: "rectangle.split.3x1"
        case .workspace: "folder"
        case .skills: "sparkles"
        case .models: "cpu"
        case .voice: "waveform"
        case .settings: "slider.horizontal.3"
        }
    }
}

private enum ToolCategory: String, CaseIterable {
    case work, agent, all
    var title: String {
        switch self {
        case .work: String(localized: "Work")
        case .agent: String(localized: "Agent")
        case .all: String(localized: "All")
        }
    }
    var destinations: [AppDestination] {
        switch self {
        case .work: [.kanban, .routines, .workspace]
        case .agent: [.skills, .models, .voice, .groups]
        case .all: [.kanban, .routines, .workspace, .skills, .models, .voice, .groups, .agents, .history, .settings]
        }
    }
}

struct SpacesView: View {
    let model: AppModel
    @State private var page: AppDestination?
    @State private var search = ""
    @State private var category: ToolCategory = .work
    @State private var detent: PresentationDetent
    @FocusState private var searching: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(model: AppModel, initial: AppDestination? = nil) {
        self.model = model
        _page = State(initialValue: initial)
        _detent = State(initialValue: initial == .profiles ? .height(380) : initial == nil ? .height(460) : .large)
    }

    var body: some View {
        Group {
            if let page { destination(page) }
            else { launcher }
        }
        .background(DS.Palette.background)
        .environment(\.toolNavigation, ToolNavigation(showSpaces: { page = nil }, showChat: { dismiss() }))
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [compactDetent, .large], selection: $detent)
        .onChange(of: page) { _, value in searching = false; detent = value == nil || value == .profiles ? compactDetent : .large }
        .onChange(of: searching) { _, value in if value { detent = .large } }
        .onChange(of: search) { _, value in if !value.isEmpty { category = .all } }
        .onChange(of: typeSize) { _, _ in detent = page == nil || page == .profiles ? compactDetent : .large }
        .onAppear { if typeSize.isAccessibilitySize { detent = .large } }
    }

    private var compactDetent: PresentationDetent { typeSize.isAccessibilitySize ? .large : .height(page == .profiles ? 380 : 460) }

    private var entries: [AppDestination] {
        category.destinations.filter { search.isEmpty || "\($0.title) \($0.detail)".localizedCaseInsensitiveContains(search) }
    }

    private var launcher: some View {
        VStack(spacing: 0) {
            ScreenHeader(Text("Tools"), subtitle: Text("For \(model.agent?.title ?? "Hermes")"), style: .title) {
                IconButton("gearshape", label: "Settings", weight: .regular) { page = .settings }
                    .accessibilityIdentifier("quick-settings")
            }.padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.xl).padding(.bottom, DS.Space.m)
            HStack(spacing: DS.Space.xxs) {
                ForEach(ToolCategory.allCases, id: \.self) { item in
                    Button { search = ""; searching = false; category = item } label: {
                        Text(item.title).textStyle(.label).frame(maxWidth: .infinity).frame(minHeight: DS.Size.tap)
                            .foregroundStyle(category == item ? DS.Palette.textPrimary : DS.Palette.textSecondary)
                            .background(category == item ? DS.Palette.surface : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }.buttonStyle(.plain).accessibilityIdentifier("tools-filter-" + item.rawValue)
                        .accessibilityAddTraits(category == item ? .isSelected : [])
                }
            }.padding(DS.Space.hairline + 1).background(DS.Palette.line.opacity(0.5), in: Capsule()).padding(.horizontal, DS.Space.l).padding(.bottom, DS.Space.s)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        Button { page = entry } label: {
                            HStack(spacing: DS.Space.s + 2) {
                                IconTile(symbol: entry.symbol)
                                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                    Text(entry.title).textStyle(.label).foregroundStyle(DS.Palette.textPrimary)
                                    Text(entry.detail).textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").icon(.xs, weight: .medium).foregroundStyle(DS.Palette.textTertiary)
                            }.padding(.vertical, DS.Space.s).contentShape(Rectangle())
                        }.buttonStyle(PressableStyle()).accessibilityIdentifier("space-\(entry.rawValue)")
                    }
                    if entries.isEmpty { ContentUnavailableView.search(text: search) }
                }.padding(.horizontal, DS.Space.screen).padding(.bottom, DS.Space.xs)
            }.scrollDismissesKeyboard(.interactively)
            HStack(spacing: DS.Space.s) {
                SearchField("Search tools", text: $search, focus: $searching, identifier: "spaces-search")
                IconButton("chevron.down", label: "Back to chat", scale: .medium, weight: .semibold) { dismiss() }
                    .accessibilityIdentifier("return-to-chat")
            }.padding(.horizontal, DS.Space.l).padding(.top, DS.Space.xs).padding(.bottom, DS.Space.s)
        }
    }

    @ViewBuilder private func destination(_ page: AppDestination) -> some View {
        switch page {
        case .spaces: launcher
        case .profiles: QuickProfilePicker(model: model, manage: { self.page = .agents }, close: { dismiss() })
        case .history: SessionsView(model: model)
        case .agents: AgentsView(model: model, openChat: { dismiss() })
        case .routines: RoutinesView(model: model)
        case .settings: SettingsView(model: model).safeAreaInset(edge: .bottom, spacing: 0) { ToolDock() }
        case .skills: SkillsView(app: model).safeAreaInset(edge: .bottom, spacing: 0) { ToolDock() }
        case .models: ModelsView(app: model).safeAreaInset(edge: .bottom, spacing: 0) { ToolDock() }
        case .workspace: WorkspaceView(app: model).safeAreaInset(edge: .bottom, spacing: 0) { ToolDock() }
        case .kanban: KanbanView(app: model)
        case .voice: VoiceView(app: model, returnToChat: { dismiss() })
        case .groups:
            Group {
                if let connection = model.activeConnection { GroupsView(app: model, connectionID: connection.id) }
                else { ContentUnavailableView("Team up", systemImage: "person.2", description: Text("Connect your Hermes to see your groups.")) }
            }.safeAreaInset(edge: .bottom, spacing: 0) { ToolDock() }
        }
    }
}

@MainActor final class ToolNavigation {
    let showSpaces: () -> Void
    let showChat: () -> Void
    init(showSpaces: @escaping () -> Void, showChat: @escaping () -> Void) {
        self.showSpaces = showSpaces; self.showChat = showChat
    }
}

private struct ToolNavigationKey: EnvironmentKey {
    static let defaultValue: ToolNavigation? = nil
}
extension EnvironmentValues {
    var toolNavigation: ToolNavigation? {
        get { self[ToolNavigationKey.self] }
        set { self[ToolNavigationKey.self] = newValue }
    }
}

/// Navigation and each screen's primary action share one compact row.
struct ToolDock<Actions: View>: View {
    @Environment(\.toolNavigation) private var navigation
    private let actions: Actions
    init(@ViewBuilder actions: () -> Actions) { self.actions = actions() }
    var body: some View {
        HStack(spacing: DS.Space.s) {
            if let navigation {
                IconButton("circle.grid.2x2", label: "Tools", weight: .regular, action: navigation.showSpaces)
                    .accessibilityIdentifier("back-to-spaces")
            }
            HStack { Spacer(minLength: 0); actions; Spacer(minLength: 0) }
                .textStyle(.label)
            if let navigation {
                Button(action: navigation.showChat) {
                    Label("Chat", systemImage: "arrow.down.right").textStyle(.label)
                        .padding(.horizontal, DS.Space.m).frame(minHeight: DS.Size.tap)
                        .background(DS.Palette.surface, in: Capsule()).overlay(Capsule().strokeBorder(DS.Palette.line))
                }.buttonStyle(PressableStyle()).accessibilityLabel("Back to chat").accessibilityIdentifier("return-to-chat")
            }
        }.buttonStyle(.plain).foregroundStyle(DS.Palette.textPrimary)
            .padding(.horizontal, DS.Space.l).padding(.vertical, DS.Space.xs)
            .background(DS.Palette.background)
    }
}
extension ToolDock where Actions == EmptyView {
    init() { self.init { EmptyView() } }
}
