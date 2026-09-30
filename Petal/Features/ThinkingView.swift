import SwiftUI

enum ThinkingPreference {
    /// App-only switch. It never changes the server's `display.show_reasoning`.
    static let showKey = "showThinking"
}

/// Reasoning effort values accepted by Hermes' `config.set reasoning` and `session.create reasoning_effort`.
enum ThinkingLevel: String, CaseIterable, Identifiable {
    case none, low, medium, high
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: String(localized: "Off", comment: "Thinking level")
        case .low: String(localized: "Low", comment: "Thinking level")
        case .medium: String(localized: "Medium", comment: "Thinking level")
        case .high: String(localized: "High", comment: "Thinking level")
        }
    }
    var symbol: String {
        switch self {
        case .none: "brain"
        case .low: "gauge.with.dots.needle.33percent"
        case .medium: "gauge.with.dots.needle.50percent"
        case .high: "gauge.with.dots.needle.100percent"
        }
    }
}

/// The model's reasoning above a reply: live while it streams, then a collapsed "Thought for 12 s" row.
struct ThinkingDisclosure: View {
    let reasoning: String
    let seconds: Double?
    /// True while the model is still reasoning (no answer text yet).
    let live: Bool
    @AppStorage(ThinkingPreference.showKey) private var show = true
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if show, !reasoning.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { expanded.toggle() }
                } label: {
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "sparkle").icon(.xs, weight: .semibold)
                            .foregroundStyle(DS.Palette.accent)
                            .symbolEffect(.pulse, options: .repeating, isActive: live && !reduceMotion)
                        Text(title).textStyle(.captionEmphasis)
                        Image(systemName: "chevron.right").icon(.xs, weight: .semibold)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .foregroundStyle(DS.Palette.textSecondary)
                    .frame(minHeight: DS.Size.tap, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(title))
                .accessibilityValue(expanded ? Text("Expanded") : Text("Collapsed"))
                .accessibilityHint(Text("Shows how the model reasoned before answering."))
                .accessibilityIdentifier("thinking-toggle")

                if expanded {
                    HStack(alignment: .top, spacing: DS.Space.s) {
                        RoundedRectangle(cornerRadius: DS.Space.hairline).fill(DS.Palette.line).frame(width: 2)
                        // Plain text: half-finished reasoning often contains unbalanced Markdown.
                        Text(verbatim: reasoning).textStyle(.subheadline).foregroundStyle(DS.Palette.textSecondary)
                            .lineSpacing(3).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("thinking-text")
                } else if live {
                    // A one-line glimpse of the latest thought while it streams.
                    Text(verbatim: lastLine).textStyle(.caption).foregroundStyle(DS.Palette.textTertiary)
                        .lineLimit(1).truncationMode(.head)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var title: String {
        if live { return String(localized: "Thinking…", comment: "Agent activity status") }
        guard let seconds, seconds >= 1 else { return String(localized: "Thoughts", comment: "Collapsed reasoning with unknown duration") }
        let duration = Duration.seconds(seconds.rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
        return String(localized: "Thought for \(duration)", comment: "Collapsed reasoning, e.g. Thought for 12 s")
    }

    private var lastLine: String {
        reasoning.split(whereSeparator: \.isNewline).last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}
