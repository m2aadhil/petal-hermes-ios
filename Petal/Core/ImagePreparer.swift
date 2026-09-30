import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An image ready to upload: resized, re-encoded and stripped of metadata.
struct PreparedImage: Sendable {
    var data: Data
    var mimeType: String
    var fileExtension: String
}

/// Shrinks images before upload so they stay sharp enough to read text in them
/// without wasting bandwidth on pixels the model would discard anyway.
///
/// - The long edge is capped at 2048 px (never upscaled).
/// - PNG sources (screenshots) and images with transparency stay lossless PNG.
///   Everything else, including HEIC, becomes JPEG.
/// - Each result must fit `byteBudget`. Quality is lowered first, resolution last,
///   because resolution matters more for reading text.
/// - Only pixels are re-encoded, so EXIF, GPS and maker data never leave the phone.
///   Orientation is applied to the pixels.
enum ImagePreparer {
    static let maxPixelSize = 2048
    static let byteBudget = 4 * 1024 * 1024
    /// Largest image file we will accept before resizing.
    static let maximumSourceBytes = 50 * 1024 * 1024
    static let jpegQualities: [CGFloat] = [0.88, 0.8, 0.72]
    static let fallbackPixelSizes = [2048, 1792, 1536, 1280]

    /// True for image types we can decode and should prepare (SVG and PDF are sent as files).
    static func handles(_ type: UTType?) -> Bool {
        guard let type, type.conforms(to: .image) else { return false }
        return !type.conforms(to: .svg)
    }

    static func prepare(_ data: Data) throws -> PreparedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw RPCFailure(String(localized: "This photo couldn’t be opened."))
        }
        let sourceType = (CGImageSourceGetType(source) as String?).flatMap(UTType.init)
        let width = (properties[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let longEdge = max(width, height)
        guard longEdge > 0 else { throw RPCFailure(String(localized: "This photo couldn’t be opened.")) }

        // Small animated GIFs keep their animation.
        if sourceType == .gif, CGImageSourceGetCount(source) > 1, data.count <= byteBudget {
            return PreparedImage(data: data, mimeType: "image/gif", fileExtension: "gif")
        }

        let hasAlpha = (properties[kCGImagePropertyHasAlpha] as? Bool) ?? false
        var lossless = hasAlpha || sourceType == .png || sourceType == .gif

        var lastTarget = 0
        for size in fallbackPixelSizes where size <= maxPixelSize {
            let target = min(size, longEdge)
            if target == lastTarget { continue } // Source is already smaller than this step.
            lastTarget = target
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: target
            ] as CFDictionary) else { throw RPCFailure(String(localized: "Couldn’t prepare the photo.")) }

            if lossless {
                if let png = encode(image, as: .png, quality: nil), png.count <= byteBudget {
                    return PreparedImage(data: png, mimeType: "image/png", fileExtension: "png")
                }
                lossless = false // Too big as PNG: fall back to JPEG at this same size.
            }
            let opaque = hasTransparency(image) ? (flattened(image) ?? image) : image
            for quality in jpegQualities {
                if let jpeg = encode(opaque, as: .jpeg, quality: quality), jpeg.count <= byteBudget {
                    return PreparedImage(data: jpeg, mimeType: "image/jpeg", fileExtension: "jpg")
                }
            }
        }
        throw RPCFailure(String(localized: "This image is too large to send, even after resizing."))
    }

    private static func encode(_ image: CGImage, as type: UTType, quality: CGFloat?) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        var options: [CFString: Any] = [:]
        if let quality { options[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    private static func hasTransparency(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }

    /// JPEG has no alpha channel: draw on white so transparent areas don't turn black.
    private static func flattened(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
