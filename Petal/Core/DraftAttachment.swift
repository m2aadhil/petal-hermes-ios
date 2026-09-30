import Foundation

struct DraftAttachment: Codable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var mimeType: String
    var size: Int
    var remotePath: String?
    var remoteReference: String?
    var runtimeID: String?
    /// Sent to the model as an image (not a file reference). `ImagePreparer` always produces one of these types.
    var isImage: Bool { ["image/png", "image/jpeg", "image/webp", "image/gif"].contains(mimeType.lowercased()) }
    static let maximumBytes = 10 * 1024 * 1024
    static let maximumCount = 4
}
