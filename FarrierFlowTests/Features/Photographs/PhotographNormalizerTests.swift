import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import FarrierFlow

@Suite("Photograph normalizer")
struct PhotographNormalizerTests {
    @Test
    func largeSourceIsDownsampledToApprovedLongestEdge() async throws {
        let source = try makeJPEG(width: 4_000, height: 2_000)
        let destination = try destinationURL(prefix: "FarrierFlow-Normalizer-Large-")

        let result = try await PhotographNormalizer().normalize(
            data: source,
            destinationURL: destination
        )
        let byteCount = try fileByteCount(at: destination)

        #expect(result.pixelWidth == 2_560)
        #expect(result.pixelHeight == 1_280)
        #expect(result.byteCount == byteCount)
        #expect(result.byteCount > 0)
    }

    @Test
    func smallSourceIsNotUpscaled() async throws {
        let source = try makeJPEG(width: 640, height: 480)
        let destination = try destinationURL(prefix: "FarrierFlow-Normalizer-Small-")

        let result = try await PhotographNormalizer().normalize(
            data: source,
            destinationURL: destination
        )

        #expect(result.pixelWidth == 640)
        #expect(result.pixelHeight == 480)
    }

    @Test
    func orientationBecomesUprightPixelsAndSourceMetadataIsRemoved() async throws {
        let source = try makeJPEG(
            width: 80,
            height: 40,
            properties: [
                kCGImagePropertyOrientation: 6,
                kCGImagePropertyGPSDictionary: [
                    kCGImagePropertyGPSLatitude: 41.0,
                    kCGImagePropertyGPSLongitude: 29.0,
                ],
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifDateTimeOriginal: "2026:07:28 12:00:00",
                ],
                kCGImagePropertyTIFFDictionary: [
                    kCGImagePropertyTIFFMake: "Source Camera",
                    kCGImagePropertyTIFFModel: "Source Device",
                ],
            ]
        )
        let destination = try destinationURL(prefix: "FarrierFlow-Normalizer-Orientation-")

        let result = try await PhotographNormalizer().normalize(
            data: source,
            destinationURL: destination
        )
        let properties = try imageProperties(at: destination)

        #expect(result.pixelWidth == 40)
        #expect(result.pixelHeight == 80)
        #expect((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1 == 1)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties[kCGImagePropertyExifDictionary] == nil)
        #expect(properties[kCGImagePropertyTIFFDictionary] == nil)
    }

    @Test
    func displayP3SourceProducesSRGBJPEG() async throws {
        let p3 = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        let source = try makeJPEG(width: 320, height: 240, colorSpace: p3)
        let destination = try destinationURL(prefix: "FarrierFlow-Normalizer-P3-")

        _ = try await PhotographNormalizer().normalize(
            data: source,
            destinationURL: destination
        )
        let image = try decodedImage(at: destination)

        #expect(image.colorSpace?.name == CGColorSpace.sRGB)
    }

    @Test
    func invalidSourceFailsWithoutCreatingDestination() async throws {
        let destination = try destinationURL(prefix: "FarrierFlow-Normalizer-Invalid-")

        await #expect(throws: PhotographNormalizationError.invalidSource) {
            try await PhotographNormalizer().normalize(
                data: Data("not an image".utf8),
                destinationURL: destination
            )
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    private func destinationURL(prefix: String) throws -> URL {
        let directory = try TemporaryStoreFixtures.makeDirectory(prefix: prefix)
        return directory.appending(path: "normalized.tmp")
    }

    private func makeJPEG(
        width: Int,
        height: Int,
        colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!,
        properties: [CFString: Any] = [:]
    ) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.55, green: 0.24, blue: 0.12, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        )
        var encodedProperties = properties
        encodedProperties[kCGImageDestinationLossyCompressionQuality] = 0.95
        CGImageDestinationAddImage(destination, image, encodedProperties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func imageProperties(at url: URL) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
    }

    private func decodedImage(at url: URL) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func fileByteCount(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.size] as? NSNumber).int64Value
    }
}
