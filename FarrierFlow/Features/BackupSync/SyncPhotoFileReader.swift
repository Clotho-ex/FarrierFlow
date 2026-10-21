import Darwin
import Foundation

/// File bytes and ImageIO work stay off the main actor. Cache only verification
/// metadata, never JPEG bytes or decoded images, and recheck the file each time.
actor SyncPhotoFileReader {
    private nonisolated struct Fingerprint: Equatable, Sendable {
        let device: Int32
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
        let changedSeconds: Int
        let changedNanoseconds: Int

        init(url: URL) throws {
            var info = stat()
            guard lstat(url.path, &info) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            guard info.st_mode & S_IFMT == S_IFREG else {
                throw PhotographFileStoreError.expectedRegularFile
            }
            device = info.st_dev
            inode = info.st_ino
            size = info.st_size
            modifiedSeconds = info.st_mtimespec.tv_sec
            modifiedNanoseconds = info.st_mtimespec.tv_nsec
            changedSeconds = info.st_ctimespec.tv_sec
            changedNanoseconds = info.st_ctimespec.tv_nsec
        }
    }

    private nonisolated struct Verification: Sendable {
        let record: SyncRecord
        let fingerprint: Fingerprint
        let receipt: SyncPhotoManifestEntry
    }

    private var verified: [UUID: Verification] = [:]

    func retain(_ ids: Set<UUID>) {
        verified = verified.filter { ids.contains($0.key) }
    }

    func payload(url: URL, record: SyncRecord) throws -> SyncPhotoPayload {
        try Task.checkCancellation()
        let before = try Fingerprint(url: url)
        let payload = try SyncPhotoPayload.validate(data: Data(contentsOf: url), record: record)
        guard try Fingerprint(url: url) == before else { throw SyncPhotoPayloadError.invalidMetadata }
        try Task.checkCancellation()
        verified[record.id] = Verification(record: record, fingerprint: before,
            receipt: .init(id: record.id, digest: payload.digest, byteCount: Int64(payload.data.count)))
        return payload
    }

    func verify(url: URL, record: SyncRecord, receipt: SyncPhotoManifestEntry) throws {
        try Task.checkCancellation()
        guard receipt.isValid, receipt.id == record.id,
              record.fields["byteCount"] == .integer(receipt.byteCount) else {
            throw SyncPhotoPayloadError.invalidMetadata
        }
        if let previous = verified[record.id], previous.record == record,
           previous.receipt == receipt, previous.fingerprint == (try Fingerprint(url: url)) {
            return
        }
        let payload = try payload(url: url, record: record)
        guard payload.digest == receipt.digest else { throw SyncPhotoPayloadError.digestMismatch }
    }
}
