import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Sync photos share local storage coordination", .serialized)
@MainActor
struct SyncPhotoLibraryTests {
    @Test(arguments: ["read", "verify", "restore"])
    func lockingDuringWorkerValidationCannotReturnBytesOrRestoreFiles(operation: String) async throws {
        let access = PhotoAccessState()
        let fixture = try await makeFixture(protectedDataAvailable: { access.check() })
        let payload = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record)
        let url = fixture.library.canonicalURL(for: fixture.record.id)
        if operation == "restore" { try fixture.library.fileStore.removeManagedFile(at: url) }
        access.checksBeforeLock = 1
        await #expect(throws: PhotographLibraryError.protectedDataUnavailable) {
            switch operation {
            case "read": _ = try await fixture.library.canonicalPayloadForSync(record: fixture.record)
            case "verify":
                _ = try await fixture.library.verifyPhotoForSync(record: fixture.record,
                    receipt: .init(id: payload.id, digest: payload.digest, byteCount: Int64(payload.data.count)))
            default: _ = try await fixture.library.restoreForSync(payload: payload, record: fixture.record, checking: {})
            }
        }
        if operation == "restore" { #expect(!FileManager.default.fileExists(atPath: url.path)) }
    }

    @Test
    func verifiedPhotoDetectsSameSizeCorruptionEvenWhenModificationDateIsRestored() async throws {
        let fixture = try await makeFixture()
        let receipt = SyncPhotoManifestEntry(id: fixture.record.id,
            digest: try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record).digest,
            byteCount: Int64(fixture.data.count))
        #expect(try await fixture.library.verifyPhotoForSync(record: fixture.record, receipt: receipt))
        #expect(try await fixture.library.verifyPhotoForSync(record: fixture.record, receipt: receipt))
        let url = fixture.library.canonicalURL(for: fixture.record.id)
        let modified = try #require(FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
        try Data(repeating: 0, count: fixture.data.count).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        await #expect(throws: SyncPhotoPayloadError.corruptPhoto) {
            try await fixture.library.verifyPhotoForSync(record: fixture.record, receipt: receipt)
        }
    }

    @Test
    func verifiedPhotoStillRequiresMatchingCloudDigestAndAnAvailableFile() async throws {
        let fixture = try await makeFixture()
        let digest = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record).digest
        let receipt = SyncPhotoManifestEntry(id: fixture.record.id, digest: digest, byteCount: Int64(fixture.data.count))
        #expect(try await fixture.library.verifyPhotoForSync(record: fixture.record, receipt: receipt))
        let wrong = SyncPhotoManifestEntry(id: receipt.id, digest: String(repeating: "0", count: 64), byteCount: receipt.byteCount)
        await #expect(throws: SyncPhotoPayloadError.digestMismatch) {
            try await fixture.library.verifyPhotoForSync(record: fixture.record, receipt: wrong)
        }
        try fixture.library.fileStore.removeManagedFile(at: fixture.library.canonicalURL(for: fixture.record.id))
        #expect(try await !fixture.library.verifyPhotoForSync(record: fixture.record, receipt: receipt))
    }

    @Test
    func readingCanonicalPhotoDoesNotRecompressAndMissingFileIsDistinct() async throws {
        let fixture = try await makeFixture()
        let payload = try await fixture.library.canonicalPayloadForSync(record: fixture.record)
        let photo = try #require(payload)
        #expect(photo.data == fixture.data)
        try fixture.library.fileStore.removeManagedFile(at: fixture.library.canonicalURL(for: photo.id))
        #expect(try await fixture.library.canonicalPayloadForSync(record: fixture.record) == nil)
    }

    @Test
    func restoringMissingPhotoIsProtectedAtomicAndIdempotent() async throws {
        let fixture = try await makeFixture()
        let payload = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record)
        let url = fixture.library.canonicalURL(for: fixture.record.id)
        try fixture.library.fileStore.removeManagedFile(at: url)
        let first = try await fixture.library.restoreForSync(payload: payload, record: fixture.record, checking: {})
        let second = try await fixture.library.restoreForSync(payload: payload, record: fixture.record, checking: {})
        #expect(first)
        #expect(!second)
        #expect(try Data(contentsOf: url) == fixture.data)
        #expect(try fixture.library.fileStore.inspectAllEntries().temporaryFiles.isEmpty)
        try await fixture.library.prepareAndReconcile()
        #expect(try Data(contentsOf: url) == fixture.data)
    }

    @Test(.enabled(if: Self.isPhysicalDevice, "File protection readback requires a physical iPhone"))
    func restoredPhotoUsesCompleteProtectionOnPhysicalDevice() async throws {
        let fixture = try await makeFixture()
        let payload = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record)
        let url = fixture.library.canonicalURL(for: fixture.record.id)
        try fixture.library.fileStore.removeManagedFile(at: url)
        _ = try await fixture.library.restoreForSync(payload: payload, record: fixture.record, checking: {})
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect(attributes[.protectionKey] as? String == FileProtectionType.complete.rawValue)
    }

    private nonisolated static var isPhysicalDevice: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    @Test
    func photoDeletedWhileDownloadAwaitsCannotBeResurrected() async throws {
        let fixture = try await makeFixture()
        let payload = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record)
        try await fixture.library.delete(id: fixture.record.id)
        await #expect(throws: PhotographLibraryError.photographUnavailable) {
            try await fixture.library.restoreForSync(payload: payload, record: fixture.record, checking: {})
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.library.canonicalURL(for: fixture.record.id).path))
    }

    @Test
    func signedOutCompletionCannotWriteDownloadedFile() async throws {
        let fixture = try await makeFixture()
        let payload = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record)
        let url = fixture.library.canonicalURL(for: fixture.record.id)
        try fixture.library.fileStore.removeManagedFile(at: url)
        await #expect(throws: CancellationError.self) {
            try await fixture.library.restoreForSync(payload: payload, record: fixture.record,
                                                     checking: { throw CancellationError() })
        }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func corruptExistingPhotoIsRetainedNotOverwrittenByRestore() async throws {
        let fixture = try await makeFixture()
        let payload = try SyncPhotoPayload.validate(data: fixture.data, record: fixture.record)
        let url = fixture.library.canonicalURL(for: fixture.record.id)
        let corrupt = Data("retained test corruption".utf8)
        try corrupt.write(to: url)
        await #expect(throws: SyncPhotoPayloadError.corruptPhoto) {
            try await fixture.library.restoreForSync(payload: payload, record: fixture.record, checking: {})
        }
        #expect(try Data(contentsOf: url) == corrupt)
    }

    private func makeFixture(
        protectedDataAvailable: @escaping @MainActor () -> Bool = { true }
    ) async throws -> (library: PhotographLibrary, record: SyncRecord, data: Data) {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Photos-")
        let library = PhotographTestFixtures.makeLibrary(graph: graph, rootURL: directory.appending(path: "HoofPhotographs"),
                                                        protectedDataAvailable: protectedDataAvailable)
        let id = try await library.add(sourceData: PhotographTestFixtures.jpeg(), to: graph.visitHorseID)
        let records = try SyncGraphCodec.capture(in: ModelContext(graph.container))
        let record = try #require(records.first { $0.id == id })
        return (library, record, try Data(contentsOf: library.canonicalURL(for: id)))
    }
}

@MainActor
private final class PhotoAccessState {
    var checksBeforeLock: Int?
    func check() -> Bool {
        guard let remaining = checksBeforeLock else { return true }
        checksBeforeLock = max(0, remaining - 1)
        return remaining > 0
    }
}
