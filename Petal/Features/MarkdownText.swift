import SwiftUI

struct MarkdownText: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ForEach(Array(ChatMarkdown.parse(text).enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block).equatable()
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MarkdownBlockView: View, Equatable {
    let block: ChatMarkdown.Block
    var body: some View {
        switch block {
        case .paragraph(let text): inline(text).textStyle(.body)
        case .heading(let level, let text):
            inline(text).font(level == 1 ? .title2.weight(.semibold) : level == 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, DS.Space.xxs).accessibilityAddTraits(.isHeader)
        case .quote(let text):
            HStack(alignment: .top, spacing: DS.Space.s) {
                RoundedRectangle(cornerRadius: DS.Space.hairline).fill(DS.Palette.accent.opacity(0.45)).frame(width: 3)
                inline(text).foregroundStyle(DS.Palette.textSecondary).lineSpacing(4)
            }.fixedSize(horizontal: false, vertical: true).padding(.vertical, DS.Space.hairline)
        case .item(let depth, let marker, let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                if let checked {
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle").foregroundStyle(DS.Palette.accent)
                        .accessibilityLabel(checked ? "Completed" : "Not completed")
                } else { Text(marker).foregroundStyle(DS.Palette.textSecondary).monospacedDigit() }
                inline(text).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.leading, CGFloat(depth) * DS.Space.m)
        case .code(let language, let text): CodeBlock(language: language, text: text)
        case .table(let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                inline(cell).textStyle(.subheadline).fontWeight(index == 0 ? .semibold : .regular)
                                    .frame(minWidth: 95, maxWidth: 230, alignment: .leading).padding(DS.Space.s)
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                                    .background(index == 0 ? DS.Palette.line : Color.clear)
                                    .overlay(alignment: .bottom) { Rectangle().fill(DS.Palette.line).frame(height: 1) }
                            }
                        }
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }.background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).strokeBorder(DS.Palette.line)).accessibilityIdentifier("markdown-table")
        case .rule: Divider().padding(.vertical, DS.Space.xxs)
        }
    }

    private func inline(_ source: String) -> Text {
        var parsed = (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(source)
        // Bare URLs (agents rarely use [text](url)), found before any edits so offsets stay valid;
        // never inside code or an existing link.
        var detected: [(offset: Int, length: Int, url: URL)] = []
        for run in parsed.runs where run.link == nil && run.inlinePresentationIntent?.contains(.code) != true {
            let text = String(parsed[run.range].characters)
            let runOffset = parsed.characters.distance(from: parsed.startIndex, to: run.range.lowerBound)
            for link in ChatMarkdown.autolinks(in: text) {
                detected.append((runOffset + text.distance(from: text.startIndex, to: link.range.lowerBound),
                                 text.distance(from: link.range.lowerBound, to: link.range.upperBound), link.url))
            }
        }
        for link in detected {
            let start = parsed.characters.index(parsed.startIndex, offsetBy: link.offset)
            parsed[start..<parsed.characters.index(start, offsetBy: link.length)].link = link.url
        }
        // No remote images or executable/custom-scheme links from generated Markdown.
        for run in parsed.runs {
            if let url = run.link, !["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { parsed[run.range].link = nil }
            if run.inlinePresentationIntent?.contains(.code) == true { parsed[run.range].font = .system(.callout, design: .monospaced) }
            // Underline links so they read as tappable, not just tinted.
            if parsed[run.range].link != nil { parsed[run.range].underlineStyle = .single }
        }
        return Text(parsed)
    }
}

private struct CodeBlock: View {
    let language: String
    let text: String
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? String(localized: "Code") : language).textStyle(.captionEmphasis).lineLimit(1)
                Spacer(minLength: 12)
                Button {
                    UIPasteboard.general.string = text; copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .textStyle(.caption).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("Copy code")
            }.foregroundStyle(DS.Palette.textSecondary).padding(.horizontal, DS.Space.s + 2)
            Divider()
            ScrollView(.horizontal) {
                Text(verbatim: text).textStyle(.code)
                    .textSelection(.enabled).fixedSize(horizontal: true, vertical: false).padding(DS.Space.s + 2)
            }
        }.background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).strokeBorder(DS.Palette.line))
            .onChange(of: text) { _, _ in copied = false }
            .task(id: copied) { if copied { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { copied = false } } }
            .accessibilityIdentifier("markdown-code")
    }
}
