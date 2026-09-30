import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PetalCore

final class ImagePreparerTests: XCTestCase {
    func testLargePhotoIsCappedAndStripped() throws {
        let source = try encode(makeImage(width: 4000, height: 3000), as: .jpeg, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 53.55, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "Test lens"]
        ])
        XCTAssertNotNil(metadata(source)[kCGImagePropertyGPSDictionary], "fixture should carry GPS")

        let result = try ImagePreparer.prepare(source)
        XCTAssertEqual(result.mimeType, "image/jpeg")
        XCTAssertEqual(result.fileExtension, "jpg")
        XCTAssertEqual(pixelSize(result.data), CGSize(width: 2048, height: 1536))
        XCTAssertNil(metadata(result.data)[kCGImagePropertyGPSDictionary])
        let exif = metadata(result.data)[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifLensModel])
    }

    func testScreenshotStaysPNG() throws {
        let result = try ImagePreparer.prepare(try encode(makeImage(width: 1290, height: 2796), as: .png))
        XCTAssertEqual(result.mimeType, "image/png")
        XCTAssertEqual(pixelSize(result.data).height, 2048)
    }

    func testTransparencyStaysPNGAndSmallImagesAreNotUpscaled() throws {
        let result = try ImagePreparer.prepare(try encode(makeImage(width: 500, height: 400, alpha: true), as: .png))
        XCTAssertEqual(result.mimeType, "image/png")
        XCTAssertEqual(pixelSize(result.data), CGSize(width: 500, height: 400))
    }

    func testOrientationIsAppliedToPixels() throws {
        let source = try encode(makeImage(width: 400, height: 200), as: .jpeg, properties: [kCGImagePropertyOrientation: 6])
        XCTAssertEqual(pixelSize(try ImagePreparer.prepare(source).data), CGSize(width: 200, height: 400))
    }

    func testNoisyImageFitsTheBudget() throws {
        // Random noise barely compresses, so the PNG is far over budget and must fall back.
        let source = try encode(makeImage(width: 2600, height: 2600, noise: true), as: .png)
        XCTAssertGreaterThan(source.count, ImagePreparer.byteBudget)
        let result = try ImagePreparer.prepare(source)
        XCTAssertLessThanOrEqual(result.data.count, ImagePreparer.byteBudget)
        XCTAssertEqual(result.mimeType, "image/jpeg")
    }

    func testRejectsDataThatIsNotAnImage() {
        XCTAssertThrowsError(try ImagePreparer.prepare(Data("hello".utf8)))
    }

    func testHandlesDecodableImageTypesOnly() {
        XCTAssertTrue(ImagePreparer.handles(.heic))
        XCTAssertTrue(ImagePreparer.handles(.png))
        XCTAssertFalse(ImagePreparer.handles(.svg))
        XCTAssertFalse(ImagePreparer.handles(.pdf))
        XCTAssertFalse(ImagePreparer.handles(nil))
    }

    func testPreparedTypesAreSentAsImages() {
        XCTAssertTrue(DraftAttachment(name: "Scan.jpg", mimeType: "image/jpeg", size: 1).isImage)
        XCTAssertTrue(DraftAttachment(name: "Screen.png", mimeType: "image/png", size: 1).isImage)
        XCTAssertFalse(DraftAttachment(name: "Photo.heic", mimeType: "image/heic", size: 1).isImage)
    }

    // MARK: - Fixtures

    private func makeImage(width: Int, height: Int, alpha: Bool = false, noise: Bool = false) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
        if noise, let pixels = context.data {
            var state: UInt64 = 0x9E37_79B9_7F4A_7C15
            let bytes = pixels.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
            for index in 0..<(context.bytesPerRow * height) {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                bytes[index] = UInt8(truncatingIfNeeded: state >> 56)
            }
        } else {
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
            context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }
        return context.makeImage()!
    }

    private func encode(_ image: CGImage, as type: UTType, properties: [CFString: Any] = [:]) throws -> Data {
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func metadata(_ data: Data) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [:] }
        return (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
    }

    private func pixelSize(_ data: Data) -> CGSize {
        let properties = metadata(data)
        return CGSize(width: (properties[kCGImagePropertyPixelWidth] as? Int) ?? 0, height: (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0)
    }
}
