import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downsample before decoding so a large HEIC doesn't become a full-resolution bitmap in memory.
enum PhotoAttachment {
    static func jpeg(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3072
              ] as CFDictionary) else { throw RPCFailure(String(localized: "This photo couldn’t be opened.")) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw RPCFailure(String(localized: "Couldn’t prepare the photo.")) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw RPCFailure(String(localized: "Couldn’t prepare the photo.")) }
        return output as Data
    }
}
