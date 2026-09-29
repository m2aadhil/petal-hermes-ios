#if DEBUG
import SwiftUI

/// Living reference for the design system. Open the canvas in Xcode
/// (light, dark and large Dynamic Type variants below) when changing tokens.
/// Strings here are verbatim or reuse existing catalog keys so the gallery
/// does not add untranslated entries to Localizable.xcstrings.
struct DesignSystemGallery: View {
    @State private var search = ""
    @State private var field = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xxl) {
                Wordmark()

                group("Type") {
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        Text(verbatim: "Hero headline").textStyle(.hero)
                        Text(verbatim: "Display title.").textStyle(.display)
                        Text(verbatim: "Section title").textStyle(.title)
                        Text(verbatim: "Headline").textStyle(.headline)
                        Text(verbatim: "Body text that wraps over a couple of lines to show line spacing in context.").textStyle(.body)
                        Text(verbatim: "Label").textStyle(.label)
                        Text(verbatim: "Caption").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                        Text(verbatim: "Overline").textStyle(.overline).foregroundStyle(DS.Palette.textSecondary)
                        Text(verbatim: "let code = true").textStyle(.code)
                    }
                }

                group("Colour") {
                    let swatches: [(String, Color)] = [
                        ("background", DS.Palette.background), ("surface", DS.Palette.surface), ("accent", DS.Palette.accent),
                        ("accentText", DS.Palette.accentText), ("success", DS.Palette.success), ("warning", DS.Palette.warning),
                        ("critical", DS.Palette.critical)
                    ]
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: DS.Space.s)], spacing: DS.Space.s) {
                        ForEach(swatches, id: \.0) { swatch in
                            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous).fill(swatch.1).frame(height: 44)
                                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous).strokeBorder(DS.Palette.line))
                                Text(verbatim: swatch.0).textStyle(.footnote).foregroundStyle(DS.Palette.textSecondary)
                            }
                        }
                    }
                }

                group("Buttons") {
                    VStack(spacing: DS.Space.s) {
                        PrimaryButton(title: "Connect my agent", symbol: "link") {}
                        PrimaryButton(title: "Connect my agent", symbol: "link", busy: true) {}
                        Button("Explore the interface") {}.buttonStyle(HermesButtonStyle(kind: .secondary))
                        Button("Explore the interface") {}.buttonStyle(HermesButtonStyle(kind: .quiet))
                        HStack(spacing: DS.Space.s) {
                            IconButton("square.and.pencil", label: "New conversation") {}
                            IconButton("arrow.up", label: "Send", style: .accent) {}
                            IconButton("xmark", label: "Close", style: .surface, scale: .large) {}
                            IconButton("mic.fill", label: "Voice conversation", style: .accent, scale: .hero) {}
                        }
                    }
                }

                group("Inputs") {
                    VStack(alignment: .leading, spacing: DS.Space.m) {
                        SearchField("Search", text: $search)
                        FormField(label: "Hermes address") { TextField("https://hermes.tailnet.ts.net", text: $field) }
                    }.card()
                }

                group("Feedback") {
                    VStack(spacing: DS.Space.s) {
                        InlineMessage("Incorrect Hermes credentials.")
                        InlineMessage("Model saved", kind: .success)
                        InlineMessage("Hermes is taking too long to respond.", kind: .info, actionTitle: "Try again") {}
                    }
                }

                group("Tiles") {
                    VStack(spacing: DS.Space.s) {
                        HStack(spacing: DS.Space.s) {
                            IconTile(symbol: "rectangle.split.3x1")
                            VStack(alignment: .leading) {
                                Text(verbatim: "Kanban").textStyle(.label)
                                Text(verbatim: "Track tasks").textStyle(.caption).foregroundStyle(DS.Palette.textSecondary)
                            }
                            Spacer()
                        }.padding(DS.Space.m).tile()
                        HStack { Text(verbatim: "Selected tile").textStyle(.label); Spacer() }.padding(DS.Space.m).tile(selected: true)
                        HStack(spacing: DS.Space.xs) {
                            StatusDot(color: DS.Palette.success); StatusDot(color: DS.Palette.warning); StatusDot(color: DS.Palette.critical)
                            AgentAvatar(name: "default", size: 34); AgentAvatar(name: "research", size: 34); AgentAvatar(name: "studio", size: 34)
                        }
                    }
                }
            }
            .padding(DS.Space.screen)
            .readableWidth()
        }
        .background(DS.Palette.background)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            SectionLabel(Text(verbatim: title))
            content()
        }
    }
}

#Preview("Light") { DesignSystemGallery() }
#Preview("Dark") { DesignSystemGallery().preferredColorScheme(.dark) }
#Preview("Accessibility XL") { DesignSystemGallery().environment(\.dynamicTypeSize, .accessibility2) }
#endif
