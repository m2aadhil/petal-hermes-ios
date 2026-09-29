import SwiftUI

/// Named text styles. All of them scale with Dynamic Type: the serif display
/// styles through `@ScaledMetric`, the rest by mapping to system text styles.
enum TextStyle {
    /// Onboarding hero headline.
    case hero
    /// Screen titles ("Your agents.").
    case display
    /// Sheet and section titles.
    case title
    /// The "Petal" wordmark.
    case wordmark
    case headline
    case body
    case bodyEmphasis
    case callout
    case subheadline
    /// Row titles and control labels.
    case label
    case caption
    case captionEmphasis
    /// Small group headings above lists.
    case sectionLabel
    case footnote
    /// Small uppercase eyebrow text ("WELCOME", Kanban columns).
    case overline
    case code
    case codeSmall

    fileprivate var scaled: (size: CGFloat, relativeTo: Font.TextStyle)? {
        switch self {
        case .hero: (40, .largeTitle)
        case .display: (32, .largeTitle)
        case .title: (26, .title)
        case .wordmark: (26, .title)
        case .overline: (11, .caption2)
        default: nil
        }
    }

    fileprivate func font(size: CGFloat) -> Font {
        switch self {
        case .hero, .display, .title: .system(size: size, weight: .regular, design: .serif)
        case .wordmark: .system(size: size, weight: .semibold, design: .rounded)
        case .overline: .system(size: size, weight: .semibold)
        case .headline: .headline
        case .body: .body
        case .bodyEmphasis: .body.weight(.semibold)
        case .callout: .callout
        case .subheadline: .subheadline
        case .label: .subheadline.weight(.medium)
        case .caption: .caption
        case .captionEmphasis: .caption.weight(.medium)
        case .sectionLabel: .caption.weight(.semibold)
        case .footnote: .caption2
        case .code: .system(.callout, design: .monospaced)
        case .codeSmall: .system(.caption, design: .monospaced)
        }
    }

    fileprivate var tracking: CGFloat {
        switch self {
        case .hero: -1.5
        case .display: -0.8
        case .title: -0.5
        case .overline: 1.5
        default: 0
        }
    }

    fileprivate var lineSpacing: CGFloat {
        switch self {
        case .body, .callout: 4
        case .subheadline: 3
        default: 0
        }
    }
}

private struct TextStyleModifier: ViewModifier {
    let style: TextStyle
    @ScaledMetric private var size: CGFloat
    init(_ style: TextStyle) {
        self.style = style
        let scaled = style.scaled ?? (17, .body)
        _size = ScaledMetric(wrappedValue: scaled.size, relativeTo: scaled.relativeTo)
    }
    func body(content: Content) -> some View {
        content
            .font(style.font(size: size))
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .textCase(style == .overline ? .uppercase : nil)
    }
}

/// SF Symbol sizes. They scale with Dynamic Type relative to body text.
enum IconSize: CGFloat {
    case xs = 10
    case s = 14
    case m = 18
    case l = 20
    case xl = 25
    case hero = 42
}

private struct IconModifier: ViewModifier {
    let weight: Font.Weight
    @ScaledMetric private var size: CGFloat
    init(_ icon: IconSize, weight: Font.Weight) {
        self.weight = weight
        _size = ScaledMetric(wrappedValue: icon.rawValue, relativeTo: .body)
    }
    func body(content: Content) -> some View { content.font(.system(size: size, weight: weight)) }
}

extension View {
    /// Applies a design-system text style.
    func textStyle(_ style: TextStyle) -> some View { modifier(TextStyleModifier(style)) }
    /// Sizes an SF Symbol on the design-system icon scale.
    func icon(_ size: IconSize, weight: Font.Weight = .regular) -> some View { modifier(IconModifier(size, weight: weight)) }
}
