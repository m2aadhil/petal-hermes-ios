import Foundation

/// A file on the Hermes server that an assistant message points at.
struct FileReference: Hashable, Identifiable, Sendable {
    enum Kind: Sendable { case image, video, audio, pdf, document, spreadsheet, presentation, archive, code, text, other }

    let path: String
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var fileExtension: String { (path as NSString).pathExtension.lowercased() }

    var kind: Kind {
        switch fileExtension {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff", "svg": .image
        case "mp4", "mov", "m4v", "webm", "mkv", "avi": .video
        case "mp3", "m4a", "wav", "aac", "flac", "ogg", "opus": .audio
        case "pdf": .pdf
        case "doc", "docx", "rtf", "odt", "pages", "epub": .document
        case "xls", "xlsx", "csv", "tsv", "ods", "numbers": .spreadsheet
        case "ppt", "pptx", "odp", "key": .presentation
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar": .archive
        case "swift", "py", "js", "ts", "tsx", "jsx", "json", "yaml", "yml", "toml", "html", "css", "sh", "rb", "go", "rs",
             "java", "kt", "c", "h", "cpp", "cs", "sql", "xml": .code
        case "txt", "md", "markdown", "log": .text
        default: .other
        }
    }
}

/// Finds file paths in agent replies so they can be offered as downloads.
///
/// Two forms are recognised:
/// - `MEDIA:/absolute/path` — Hermes' native file-delivery directive (desktop and messaging surfaces).
/// - A bare absolute path ending in a file extension, e.g. `/tmp/report.pdf` or `~/out/chart.png`,
///   including inside backticks. URLs and relative paths are ignored.
enum FileReferences {
    static let maximumCount = 8

    /// `MEDIA:` path, without trailing sentence punctuation (same rule as the Hermes desktop app).
    nonisolated(unsafe) private static let mediaPattern = try! NSRegularExpression(pattern: #"MEDIA:(\S+?)(?=[.,;:!?)\]}"'`*_]*(?:\s|$))"#)
    nonisolated(unsafe) private static let mediaDirective = try! NSRegularExpression(pattern: #"[ \t]*MEDIA:\S+?(?=[.,;:!?)\]}"'`*_]*(?:\s|$))"#)
    /// Absolute (or ~/) path whose last component has an extension containing a letter.
    /// Not preceded by a word character, ':' , '/' or '.', which rules out URLs and relative paths.
    nonisolated(unsafe) private static let pathPattern = try! NSRegularExpression(
        pattern: #"(?<![\w:/.~])(~?/(?:[^\s`'"<>()\[\]{}|*,;]+/)*[^\s`'"<>()\[\]{}|*,;/]+\.(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{1,8})(?![\w/])"#)

    static func extract(from text: String) -> [FileReference] {
        let range = NSRange(text.startIndex..., in: text)
        var found: [(Int, String)] = []
        for match in mediaPattern.matches(in: text, range: range) {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let path = String(text[r])
            if isFilePath(path) { found.append((match.range.location, path)) }
        }
        for match in pathPattern.matches(in: text, range: range) {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let start = match.range(at: 1).location
            // Already covered by a MEDIA: directive.
            if start >= 6, (text as NSString).substring(with: NSRange(location: start - 6, length: 6)) == "MEDIA:" { continue }
            found.append((start, String(text[r])))
        }
        var seen = Set<String>(), result: [FileReference] = []
        for (_, path) in found.sorted(by: { $0.0 < $1.0 }) where seen.insert(path).inserted {
            result.append(FileReference(path: path))
            if result.count == maximumCount { break }
        }
        return result
    }

    /// Removes `MEDIA:` directives from the text shown to the user; the files appear as chips instead.
    static func stripMediaDirectives(_ text: String) -> String {
        guard text.contains("MEDIA:") else { return text }
        let lines = text.components(separatedBy: "\n").compactMap { line -> String? in
            let stripped = mediaDirective.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "")
            // Drop lines that held nothing but directives.
            if stripped.trimmingCharacters(in: .whitespaces).isEmpty, !line.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
            return stripped
        }
        return lines.joined(separator: "\n")
    }

    private static func isFilePath(_ path: String) -> Bool {
        (path.hasPrefix("/") || path.hasPrefix("~/")) && !(path as NSString).pathExtension.isEmpty
    }
}
