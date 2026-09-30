import QuickLook
import SwiftUI

/// Downloads files the agent mentions and hands them to Quick Look, which also offers Share / Save to Files.
@MainActor @Observable
final class FileDownloads {
    @ObservationIgnored weak var model: AppModel?
    private(set) var active: Set<String> = []
    var preview: URL?

    func open(_ reference: FileReference) {
        guard !active.contains(reference.path), let model else { return }
        active.insert(reference.path)
        Task {
            defer { active.remove(reference.path) }
            do { preview = try await model.downloadFile(reference) }
            catch is CancellationError { }
            catch { model.notice = error.localizedDescription }
        }
    }
}

/// Files referenced by an assistant reply, shown as tappable cards below it.
struct FileChips: View {
    let references: [FileReference]
    @Environment(FileDownloads.self) private var downloads: FileDownloads?

    var body: some View {
        if let downloads, !references.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                ForEach(references) { reference in
                    FileChip(reference: reference, loading: downloads.active.contains(reference.path)) { downloads.open(reference) }
                }
            }
        }
    }
}

private struct FileChip: View {
    let reference: FileReference
    let loading: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: DS.Space.s) {
                IconTile(symbol: symbol, size: 36)
                VStack(alignment: .leading, spacing: DS.Space.hairline) {
                    Text(verbatim: reference.name).textStyle(.subheadline).lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(DS.Palette.textPrimary)
                    Text(verbatim: folder).textStyle(.caption).lineLimit(1).truncationMode(.head)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
                Spacer(minLength: DS.Space.xs)
                Group {
                    if loading { ProgressView() }
                    else { Image(systemName: "arrow.down.circle").icon(.m).foregroundStyle(DS.Palette.accentText) }
                }.frame(width: DS.Size.tap, height: DS.Size.tap)
            }
            .padding(.leading, DS.Space.xs).frame(minHeight: DS.Size.tap + DS.Space.xs)
            .frame(maxWidth: 360, alignment: .leading)
            .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous).strokeBorder(DS.Palette.line))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(loading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("File: \(reference.name)"))
        .accessibilityValue(loading ? Text("Downloading…") : Text(verbatim: ""))
        .accessibilityHint(Text("Downloads the file from Hermes and opens a preview."))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("file-chip")
    }

    private var folder: String {
        let parent = (reference.path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    private var symbol: String {
        switch reference.kind {
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .pdf: "doc.richtext"
        case .document: "doc.text"
        case .spreadsheet: "tablecells"
        case .presentation: "rectangle.on.rectangle"
        case .archive: "doc.zipper"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .text: "doc.plaintext"
        case .other: "doc"
        }
    }
}
