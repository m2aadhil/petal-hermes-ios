import SwiftUI

// MARK: - Buttons

/// Full-width call-to-action styles.
struct HermesButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    var kind: Kind = .primary
    var fullWidth = true
    func makeBody(configuration: Configuration) -> some View {
        HermesButtonBody(configuration: configuration, kind: kind, fullWidth: fullWidth)
    }
}

private struct HermesButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: HermesButtonStyle.Kind
    let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .textStyle(kind == .quiet ? .label : .bodyEmphasis)
            .padding(.horizontal, DS.Space.l)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: kind == .quiet ? DS.Size.tap : DS.Size.button)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
            .overlay {
                if kind == .secondary { RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous).strokeBorder(DS.Palette.line) }
            }
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
    private var foreground: Color {
        switch kind {
        case .primary: DS.Palette.onAccent
        case .secondary: DS.Palette.textPrimary
        case .quiet: DS.Palette.textSecondary
        }
    }
    private var background: Color {
        switch kind {
        case .primary: DS.Palette.accent
        case .secondary: DS.Palette.surface
        case .quiet: .clear
        }
    }
}

/// Subtle press feedback for custom-drawn buttons (rows, tiles, icon buttons).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { PressableBody(configuration: configuration) }
}

private struct PressableBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// The app's primary action: accent fill, trailing symbol, optional busy state.
struct PrimaryButton: View {
    var title: LocalizedStringKey
    var symbol: String = "arrow.right"
    var busy = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                Text(title)
                if busy { ProgressView().tint(DS.Palette.onAccent) }
                else { Image(systemName: symbol).accessibilityHidden(true) }
            }
        }
        .buttonStyle(HermesButtonStyle(kind: .primary))
        .disabled(busy)
    }
}

/// Circular icon-only button. Always provide an accessibility label.
struct IconButton: View {
    enum Style { case surface, plain, accent, subtle }
    enum Scale {
        /// 44 pt, 48 pt (matches search fields), 58 pt, 76 pt.
        case regular, medium, large, hero
        var diameter: CGFloat {
            switch self {
            case .regular: DS.Size.tap
            case .medium: DS.Size.control
            case .large: DS.Size.voiceSecondary
            case .hero: DS.Size.voicePrimary
            }
        }
        var icon: IconSize {
            switch self {
            case .regular, .medium: .m
            case .large: .l
            case .hero: .xl
            }
        }
    }

    let symbol: String
    let label: LocalizedStringKey
    var style: Style = .surface
    var scale: Scale = .regular
    var weight: Font.Weight = .medium
    let action: () -> Void

    init(_ symbol: String, label: LocalizedStringKey, style: Style = .surface, scale: Scale = .regular, weight: Font.Weight = .medium, action: @escaping () -> Void) {
        self.symbol = symbol; self.label = label; self.style = style; self.scale = scale; self.weight = weight; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .icon(scale.icon, weight: weight)
                .foregroundStyle(foreground)
                .frame(width: scale.diameter, height: scale.diameter)
                .background(background, in: Circle())
                .overlay { if style == .surface { Circle().strokeBorder(DS.Palette.line) } }
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
    private var foreground: Color {
        switch style {
        case .surface, .plain: DS.Palette.textPrimary
        case .accent: DS.Palette.onAccent
        case .subtle: DS.Palette.textSecondary
        }
    }
    private var background: Color {
        switch style {
        case .surface: DS.Palette.surface
        case .accent: DS.Palette.accent
        case .plain, .subtle: .clear
        }
    }
}

// MARK: - Surfaces

extension View {
    /// A raised card: surface fill, hairline border, generous padding.
    func card(padding: CGFloat = DS.Space.l) -> some View {
        self.padding(padding)
            .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).strokeBorder(DS.Palette.line))
    }

    /// A tappable list tile (conversations, tasks, suggestions). Selected tiles get an accent wash.
    func tile(selected: Bool = false, radius: CGFloat = DS.Radius.m) -> some View {
        background(selected ? DS.Palette.accentSoft : DS.Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(selected ? DS.Palette.accent.opacity(0.2) : DS.Palette.line))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Transparent row that gains a surface background when selected (agent pickers).
    func rowHighlight(_ selected: Bool, radius: CGFloat = DS.Radius.l) -> some View {
        background(selected ? DS.Palette.surface : Color.clear, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Recessed text-field container.
    func fieldStyle() -> some View {
        textStyle(.body)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .frame(minHeight: DS.Size.control)
            .background(DS.Palette.sunken, in: RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
    }

    /// Caps content at a readable width and centres it.
    func readableWidth(_ width: CGFloat = DS.Size.contentWidth) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }

    /// Applies `transform` only when `value` is non-nil.
    @ViewBuilder func ifLet<T, V: View>(_ value: T?, _ transform: (Self, T) -> V) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

// MARK: - Fields

/// Label above a recessed input.
struct FormField<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(label).textStyle(.captionEmphasis).foregroundStyle(DS.Palette.textSecondary)
            content.fieldStyle()
        }
    }
}

/// Capsule search field with a clear button.
struct SearchField: View {
    let prompt: LocalizedStringKey
    @Binding var text: String
    var focus: FocusState<Bool>.Binding?
    var identifier: String?
    var label: LocalizedStringKey?

    init(_ prompt: LocalizedStringKey, text: Binding<String>, focus: FocusState<Bool>.Binding? = nil, identifier: String? = nil, label: LocalizedStringKey? = nil) {
        self.prompt = prompt; _text = text; self.focus = focus; self.identifier = identifier; self.label = label
    }

    var body: some View {
        HStack(spacing: DS.Space.xs + 2) {
            Image(systemName: "magnifyingglass").icon(.s).foregroundStyle(DS.Palette.textTertiary).accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textStyle(.subheadline)
                .ifLet(focus) { $0.focused($1) }
                .ifLet(identifier) { $0.accessibilityIdentifier($1) }
                .ifLet(label) { $0.accessibilityLabel($1) }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Palette.textTertiary)
                        .frame(width: 28, height: DS.Size.tap)
                }.buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DS.Space.m)
        .frame(minHeight: DS.Size.control)
        .background(DS.Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.Palette.line))
    }
}

// MARK: - Headings

/// Serif screen title with optional subtitle and trailing accessory.
struct ScreenHeader<Trailing: View>: View {
    let title: Text
    var subtitle: Text?
    var style: TextStyle
    let trailing: Trailing

    init(_ title: Text, subtitle: Text? = nil, style: TextStyle = .display, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.subtitle = subtitle; self.style = style; self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: DS.Space.xs - 2) {
                title.textStyle(style).accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle { subtitle.textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(_ title: Text, subtitle: Text? = nil, style: TextStyle = .display) {
        self.init(title, subtitle: subtitle, style: style) { EmptyView() }
    }
}

/// Small heading above a group of rows.
struct SectionLabel: View {
    let text: Text
    init(_ text: Text) { self.text = text }
    var body: some View {
        text.textStyle(.sectionLabel).foregroundStyle(DS.Palette.textSecondary)
            .padding(.horizontal, DS.Space.xxs)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Feedback

/// Inline banner for errors and notices, with an optional action.
struct InlineMessage: View {
    enum Kind {
        case error, info, success
        var symbol: String {
            switch self {
            case .error: "exclamationmark.circle.fill"
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            }
        }
        var tint: Color {
            switch self {
            case .error: DS.Palette.critical
            case .info: DS.Palette.textSecondary
            case .success: DS.Palette.success
            }
        }
    }

    let text: String
    var kind: Kind = .error
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    init(_ text: String, kind: Kind = .error, actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.text = text; self.kind = kind; self.actionTitle = actionTitle; self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s - 2) {
            Image(systemName: kind.symbol).foregroundStyle(kind.tint).accessibilityHidden(true)
            Text(verbatim: text).textStyle(.subheadline).foregroundStyle(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action).textStyle(.captionEmphasis).foregroundStyle(DS.Palette.accentText)
            }
        }
        .padding(DS.Space.s + 2)
        .background(kind.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// A small coloured status dot.
struct StatusDot: View {
    let color: Color
    var size: CGFloat = DS.Size.dot
    var body: some View { Circle().fill(color).frame(width: size, height: size).accessibilityHidden(true) }
}

/// Tinted rounded square behind a symbol (tool list, conversation rows).
struct IconTile: View {
    let symbol: String
    var tint: Color = DS.Palette.accent
    var size: CGFloat = DS.Size.iconTile
    var filled = true
    var body: some View {
        Image(systemName: symbol)
            .icon(size >= DS.Size.iconTile ? .m : .s)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(filled ? tint.opacity(0.08) : DS.Palette.sunken, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Live connection state shown under the agent name.
struct ConnectionIndicator: View {
    let model: AppModel
    var body: some View {
        HStack(spacing: DS.Space.xs - 2) {
            StatusDot(color: model.demo || model.state == .connected ? DS.Palette.success : DS.Palette.warning, size: 5)
            Text(model.demo ? "Interactive preview" : model.state == .connected ? "Connected to Hermes" : model.state == .signInRequired ? "Session expired" : model.state == .connecting ? "Reconnecting…" : "Offline · draft saved")
                .textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
        }.accessibilityElement(children: .combine)
    }
}

// MARK: - Layout helpers

extension View {
    @ViewBuilder func chatScrollAnchors() -> some View {
        if #available(iOS 18.0, *) {
            // Open at the bottom, but let size changes (expanding Thinking, keyboard, a growing
            // composer) keep what's on screen in place. ChatView follows streaming replies itself.
            self.defaultScrollAnchor(.bottom, for: .initialOffset)
                .defaultScrollAnchor(.top, for: .sizeChanges)
                .defaultScrollAnchor(.top, for: .alignment)
        } else {
            self.defaultScrollAnchor(.bottom)
        }
    }

    /// Plain list on the app background.
    func modernList() -> some View {
        listStyle(.plain).scrollContentBackground(.hidden).background(DS.Palette.background)
            .environment(\.defaultMinListRowHeight, 54)
    }
}
