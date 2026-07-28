import CoreGraphics
import Foundation
import ImageIO
import Testing
import UIKit
@testable import FarrierFlow

@Suite("Camera capture result adapter")
@MainActor
struct CameraCaptureResultAdapterTests {
    @Test
    func imageURLOnlyInputUsesReadableFileData() async throws {
        let data = try PhotographTestFixtures.jpeg()
        let url = try sourceURL(data: data)

        let result = try await CameraCaptureResultAdapter.sourceData(from: [.imageURL: url])

        #expect(result == data)
    }

    @Test
    func originalImageOnlyInputProducesTransientImageData() async throws {
        let image = try image(width: 80, height: 40)

        let result = try await CameraCaptureResultAdapter.sourceData(from: [.originalImage: image])

        #expect(!result.isEmpty)
        #expect(UIImage(data: result) != nil)
    }

    @Test
    func unreadableImageURLFallsBackToOriginalImage() async throws {
        let image = try image(width: 80, height: 40)
        let missingURL = URL(filePath: "/private/tmp/missing-camera-capture.jpg")

        let result = try await CameraCaptureResultAdapter.sourceData(
            from: [.imageURL: missingURL, .originalImage: image]
        )

        #expect(!result.isEmpty)
        #expect(UIImage(data: result) != nil)
    }

    @Test
    func originalImageFallbackPreservesVisibleOrientation() async throws {
        let baseImage = try image(width: 80, height: 40)
        let cgImage = try #require(baseImage.cgImage)
        let orientedImage = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
        let data = try await CameraCaptureResultAdapter.sourceData(from: [.originalImage: orientedImage])
        let destination = try normalizedDestination()

        let normalized = try await PhotographNormalizer().normalize(
            data: data,
            destinationURL: destination
        )

        #expect(normalized.pixelWidth == 40)
        #expect(normalized.pixelHeight == 80)
    }

    @Test
    func readableButCorruptImageURLFallsBackToOriginalImage() async throws {
        let url = try sourceURL(data: Data("not an image".utf8))
        let image = try image(width: 80, height: 40)

        let result = try await CameraCaptureResultAdapter.sourceData(
            from: [.imageURL: url, .originalImage: image]
        )

        #expect(UIImage(data: result) != nil)
    }

    @Test
    func invalidOrMissingValuesFailCleanly() async {
        await #expect(throws: CameraCaptureResultError.unreadableCapture) {
            try await CameraCaptureResultAdapter.sourceData(from: [:])
        }
        await #expect(throws: CameraCaptureResultError.unreadableCapture) {
            try await CameraCaptureResultAdapter.sourceData(
                from: [.imageURL: "not a URL", .originalImage: "not an image"]
            )
        }
    }

    @Test
    func fallbackNormalizedJPEGContainsNoSourceMetadata() async throws {
        let image = try image(width: 80, height: 40)
        let sourceData = try await CameraCaptureResultAdapter.sourceData(from: [.originalImage: image])
        let destination = try normalizedDestination()

        _ = try await PhotographNormalizer().normalize(
            data: sourceData,
            destinationURL: destination
        )
        let properties = try properties(at: destination)

        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties[kCGImagePropertyExifDictionary] == nil)
        #expect(properties[kCGImagePropertyTIFFDictionary] == nil)
        #expect((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1 == 1)
    }

    private func sourceURL(data: Data) throws -> URL {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Camera-Adapter-"
        )
        let url = directory.appending(path: "capture.jpg")
        try data.write(to: url)
        return url
    }

    private func normalizedDestination() throws -> URL {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Camera-Normalized-"
        )
        return directory.appending(path: "normalized.tmp")
    }

    private func image(width: Int, height: Int) throws -> UIImage {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return UIImage(cgImage: try #require(context.makeImage()))
    }

    private func properties(at url: URL) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
    }
}
