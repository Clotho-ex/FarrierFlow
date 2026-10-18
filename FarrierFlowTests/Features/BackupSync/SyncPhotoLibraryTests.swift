import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Sync photos share local storage coordination", .serialized)
@MainActor
struct SyncPhotoLibraryTests {
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

    private func makeFixture() async throws -> (library: PhotographLibrary, record: SyncRecord, data: Data) {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Photos-")
        let library = PhotographTestFixtures.makeLibrary(graph: graph, rootURL: directory.appending(path: "HoofPhotographs"))
        let id = try await library.add(sourceData: PhotographTestFixtures.jpeg(), to: graph.visitHorseID)
        let records = try SyncGraphCodec.capture(in: ModelContext(graph.container))
        let record = try #require(records.first { $0.id == id })
        return (library, record, try Data(contentsOf: library.canonicalURL(for: id)))
    }
}
