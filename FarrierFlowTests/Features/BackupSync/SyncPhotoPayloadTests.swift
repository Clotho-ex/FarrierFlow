import CryptoKit
import Foundation
import Testing
@testable import FarrierFlow

@Suite("Canonical sync photo integrity")
struct SyncPhotoPayloadTests {
    @Test
    func originalJPEGIsPreservedByteForByteAndHasStableDigest() throws {
        let data = try PhotographTestFixtures.jpeg(width: 80, height: 60)
        let record = metadata(byteCount: data.count)
        let payload = try SyncPhotoPayload.validate(data: data, record: record)
        #expect(payload.id == record.id)
        #expect(payload.data == data)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(payload.digest == digest)
        #expect(try SyncPhotoPayload.validate(data: data, record: record, expectedDigest: digest) == payload)
    }

    @Test
    func validJPEGWithWrongManifestHashIsNotAccepted() throws {
        let data = try PhotographTestFixtures.jpeg()
        #expect(throws: SyncPhotoPayloadError.digestMismatch) {
            try SyncPhotoPayload.validate(data: data, record: metadata(byteCount: data.count),
                                          expectedDigest: String(repeating: "0", count: 64))
        }
    }

    @Test
    func truncatedOrNonImageBytesNeverBecomeProtectedPhoto() throws {
        let complete = try PhotographTestFixtures.jpeg()
        for data in [Data(complete.prefix(40)), Data("not a JPEG".utf8)] {
            #expect(throws: SyncPhotoPayloadError.corruptPhoto) {
                try SyncPhotoPayload.validate(data: data, record: metadata(byteCount: data.count))
            }
        }
    }

    @Test
    func declaredDimensionsAndExactByteCountMustMatchJPEG() throws {
        let data = try PhotographTestFixtures.jpeg()
        #expect(throws: SyncPhotoPayloadError.corruptPhoto) {
            try SyncPhotoPayload.validate(data: data, record: metadata(byteCount: data.count + 1))
        }
        #expect(throws: SyncPhotoPayloadError.corruptPhoto) {
            try SyncPhotoPayload.validate(data: data, record: metadata(byteCount: data.count, width: 81))
        }
    }

    private func metadata(byteCount: Int, width: Int64 = 80) -> SyncRecord {
        .init(id: UUID(), kind: .photograph, fields: [
            "byteCount": .integer(Int64(byteCount)), "pixelWidth": .integer(width),
            "pixelHeight": .integer(60)
        ])
    }
}
