import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated struct PhotographNormalizer: Sendable {
    private let writeData: @Sendable (Data, URL) throws -> Void

    init(
        writeData: @escaping @Sendable (Data, URL) throws -> Void = Self.writeWithoutOverwriting
    ) {
        self.writeData = writeData
    }

    func normalize(
        data: Data,
        destinationURL: URL
    ) async throws -> NormalizedPhotograph {
        let writeData = writeData
        return try await Task.detached(priority: .userInitiated) {
            try Self.normalizeSynchronously(
                data: data,
                destinationURL: destinationURL,
                writeData: writeData
            )
        }.value
    }

    private static func normalizeSynchronously(
        data: Data,
        destinationURL: URL,
        writeData: @escaping @Sendable (Data, URL) throws -> Void
    ) throws -> NormalizedPhotograph {
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw PhotographNormalizationError.destinationExists
        }
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
        CGImageSourceGetCount(source) > 0,
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) as? [CFString: Any],
        let sourceWidth = (sourceProperties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
        let sourceHeight = (sourceProperties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
        sourceWidth > 0,
        sourceHeight > 0
        else {
            throw PhotographNormalizationError.invalidSource
        }

        let targetLongestEdge = min(
            max(sourceWidth, sourceHeight),
            PhotographConstants.maximumLongestEdge
        )
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetLongestEdge,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let downsampled = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ),
        downsampled.width > 0,
        downsampled.height > 0,
        max(downsampled.width, downsampled.height)
            <= PhotographConstants.maximumLongestEdge,
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil,
            width: downsampled.width,
            height: downsampled.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
        else {
            throw PhotographNormalizationError.renderFailed
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(
            CGRect(x: 0, y: 0, width: downsampled.width, height: downsampled.height)
        )
        context.interpolationQuality = .high
        context.draw(
            downsampled,
            in: CGRect(x: 0, y: 0, width: downsampled.width, height: downsampled.height)
        )
        guard let rendered = context.makeImage() else {
            throw PhotographNormalizationError.renderFailed
        }

        let encodedData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encodedData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw PhotographNormalizationError.encodingFailed
        }
        CGImageDestinationAddImageAndMetadata(
            destination,
            rendered,
            CGImageMetadataCreateMutable(),
            [
                kCGImageDestinationLossyCompressionQuality:
                    PhotographConstants.jpegQuality,
                kCGImageDestinationEmbedThumbnail: false,
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw PhotographNormalizationError.encodingFailed
        }

        do {
            let metadataFreeData = try removingJPEGMetadataSegments(
                from: encodedData as Data
            )
            try writeData(metadataFreeData, destinationURL)
            return try validateOutput(at: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    private static func writeWithoutOverwriting(
        _ data: Data,
        _ destinationURL: URL
    ) throws {
        try data.write(to: destinationURL, options: .withoutOverwriting)
    }

    private static func validateOutput(at url: URL) throws -> NormalizedPhotograph {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
        CGImageSourceGetType(source) == UTType.jpeg.identifier as CFString?,
        let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) as? [CFString: Any],
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
        width > 0,
        height > 0,
        max(width, height) <= PhotographConstants.maximumLongestEdge,
        let image = CGImageSourceCreateImageAtIndex(
            source,
            0,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
        let size = try FileManager.default.attributesOfItem(
            atPath: url.path
        )[.size] as? NSNumber,
        size.int64Value > 0
        else {
            throw PhotographNormalizationError.validationFailed
        }
        guard
            properties[kCGImagePropertyGPSDictionary] == nil,
            properties[kCGImagePropertyExifDictionary] == nil,
            properties[kCGImagePropertyTIFFDictionary] == nil
        else {
            throw PhotographNormalizationError.metadataPresent
        }
        guard (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1 == 1 else {
            throw PhotographNormalizationError.validationFailed
        }
        guard image.colorSpace?.name == CGColorSpace.sRGB else {
            throw PhotographNormalizationError.colorSpaceMismatch
        }

        return NormalizedPhotograph(
            pixelWidth: width,
            pixelHeight: height,
            byteCount: size.int64Value
        )
    }

    private static func removingJPEGMetadataSegments(from data: Data) throws -> Data {
        guard data.count >= 4, data[0] == 0xFF, data[1] == 0xD8 else {
            throw PhotographNormalizationError.encodingFailed
        }

        var output = Data(data.prefix(2))
        var offset = 2

        while offset < data.count {
            guard data[offset] == 0xFF else {
                throw PhotographNormalizationError.encodingFailed
            }

            let markerStart = offset
            while offset < data.count, data[offset] == 0xFF {
                offset += 1
            }
            guard offset < data.count else {
                throw PhotographNormalizationError.encodingFailed
            }

            let marker = data[offset]
            offset += 1
            if marker == 0xDA {
                output.append(data[markerStart...])
                return output
            }
            if marker == 0xD9 {
                output.append(data[markerStart..<offset])
                return output
            }
            if marker == 0x01 || (0xD0...0xD8).contains(marker) {
                output.append(data[markerStart..<offset])
                continue
            }

            guard offset + 1 < data.count else {
                throw PhotographNormalizationError.encodingFailed
            }
            let segmentLength = Int(data[offset]) << 8 | Int(data[offset + 1])
            guard segmentLength >= 2, offset + segmentLength <= data.count else {
                throw PhotographNormalizationError.encodingFailed
            }

            let segmentEnd = offset + segmentLength
            let isMetadataSegment = marker == 0xE1 || marker == 0xED || marker == 0xFE
            if !isMetadataSegment {
                output.append(data[markerStart..<segmentEnd])
            }
            offset = segmentEnd
        }

        throw PhotographNormalizationError.encodingFailed
    }
}
