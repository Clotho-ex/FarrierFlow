import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum SyncPhotoPayloadError: Error, Equatable {
    case invalidMetadata
    case corruptPhoto
    case digestMismatch
}

nonisolated struct SyncPhotoPayload: Equatable, Sendable {
    let id: UUID
    let data: Data
    let digest: String

    private init(id: UUID, data: Data, digest: String) {
        self.id = id
        self.data = data
        self.digest = digest
    }

    static func validate(
        data: Data, record: SyncRecord, expectedDigest: String? = nil
    ) throws -> Self {
        guard record.kind == .photograph,
              case .integer(let byteCount)? = record.fields["byteCount"],
              case .integer(let width)? = record.fields["pixelWidth"],
              case .integer(let height)? = record.fields["pixelHeight"],
              byteCount > 0, byteCount <= 20 * 1_024 * 1_024,
              width > 0, height > 0,
              width <= PhotographConstants.maximumLongestEdge,
              height <= PhotographConstants.maximumLongestEdge else {
            throw SyncPhotoPayloadError.invalidMetadata
        }
        guard Int64(data.count) == byteCount,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) == UTType.jpeg.identifier as CFString,
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.int64Value == width,
              (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.int64Value == height,
              let image = CGImageSourceCreateImageAtIndex(source, 0, [
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), image.width == width, image.height == height else {
            throw SyncPhotoPayloadError.corruptPhoto
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard expectedDigest == nil || expectedDigest == digest else {
            throw SyncPhotoPayloadError.digestMismatch
        }
        // Deliberately retain the canonical bytes: validation is not another
        // normalization/recompression pass and cannot lower image quality.
        return Self(id: record.id, data: data, digest: digest)
    }
}
