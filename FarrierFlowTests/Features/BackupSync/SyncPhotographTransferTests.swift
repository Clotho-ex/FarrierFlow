import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Retryable cloud photographs", .serialized)
@MainActor
struct SyncPhotographTransferTests {
    @Test
    func originalPhotoUploadsAndOnlyVerifiedReceiptBecomesProtected() async throws {
        let fixture = try await makeFixture()
        let report = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(report.protectedIDs == [fixture.payload.id])
        #expect(report.missingIDs.isEmpty)
        #expect(report.needsReviewIDs.isEmpty)
        #expect(try fixture.store.journal()?.verifiedPhotoReceipts.map(\.id) == [fixture.payload.id])
        #expect(await fixture.transport.object(fixture.payload.id) == fixture.payload.data)
    }

    @Test
    func absentLocalFileRestoresVerifiedRemoteOriginal() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.seed(fixture.payload, withManifest: true)
        let url = fixture.library.canonicalURL(for: fixture.payload.id)
        try fixture.library.fileStore.removeManagedFile(at: url)
        let report = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(report.protectedIDs == [fixture.payload.id])
        #expect(try Data(contentsOf: url) == fixture.payload.data)
        #expect(await fixture.transport.uploadCount == 0)
    }

    @Test
    func lostCommitReceiptIsRecoveredWithoutReplacingCloudObject() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.loseNextCommitReceipt()
        await #expect(throws: URLError.self) {
            try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        }
        #expect(try fixture.store.journal()?.verifiedPhotoReceipts.isEmpty == true)
        let report = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(report.protectedIDs == [fixture.payload.id])
        #expect(await fixture.transport.uploadCount == 1)
        #expect(await fixture.transport.object(fixture.payload.id) == fixture.payload.data)
    }

    @Test
    func uploadedObjectWithoutManifestIsVerifiedBeforeRetryCommit() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.seed(fixture.payload, withManifest: false)
        let report = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(report.protectedIDs == [fixture.payload.id])
        #expect(await fixture.transport.downloadCount == 1)
        #expect(await fixture.transport.object(fixture.payload.id) == fixture.payload.data)
    }

    @Test
    func metadataAloneNeverClaimsMissingPhotoIsBackedUp() async throws {
        let fixture = try await makeFixture()
        try fixture.library.fileStore.removeManagedFile(at: fixture.library.canonicalURL(for: fixture.payload.id))
        let report = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(report.missingIDs == [fixture.payload.id])
        #expect(report.protectedIDs.isEmpty)
        #expect(try fixture.store.journal()?.verifiedPhotoReceipts.isEmpty == true)
        #expect(await fixture.transport.uploadCount == 0)
    }

    @Test
    func corruptRemoteHashNeedsReviewAndCannotWriteCanonicalFile() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.seed(fixture.payload, withManifest: true, corruptDigest: true)
        let url = fixture.library.canonicalURL(for: fixture.payload.id)
        try fixture.library.fileStore.removeManagedFile(at: url)
        let report = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(report.needsReviewIDs == [fixture.payload.id])
        #expect(report.protectedIDs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(try fixture.store.journal()?.verifiedPhotoReceipts.isEmpty == true)
    }

    @Test
    func wrongAppleAccountDoesNotStartPhotoCloudRequests() async throws {
        let fixture = try await makeFixture()
        await #expect(throws: SyncJournalError.accountMismatch) {
            try await fixture.transfer.sync(accountID: UUID(), checking: {})
        }
        #expect(await fixture.transport.manifestCount == 0)
    }

    private func makeFixture() async throws -> Fixture {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let root = try TemporaryStoreFixtures.makeDirectory(prefix: "Cloud-Photos-")
        let library = PhotographTestFixtures.makeLibrary(graph: graph, rootURL: root.appending(path: "HoofPhotographs"))
        let id = try await library.add(sourceData: PhotographTestFixtures.jpeg(), to: graph.visitHorseID)
        let store = SyncJournalStore(container: graph.container)
        let account = UUID()
        try store.bind(accountID: account, workspaceID: UUID(), deviceID: UUID())
        let staged = try store.stage()
        let batch = try #require(staged)
        try store.acknowledge(operationID: batch.operationID, revision: 1)
        let records = try SyncGraphCodec.capture(in: ModelContext(graph.container))
        let record = try #require(records.first { $0.id == id })
        let payload = try SyncPhotoPayload.validate(data: Data(contentsOf: library.canonicalURL(for: id)), record: record)
        let transport = PhotographTransferTransport()
        return Fixture(account: account, library: library, store: store, payload: payload,
            transport: transport, transfer: SyncPhotographTransfer(store: store, library: library, transport: transport))
    }

    @Test
    func acknowledgedPhotoDeletionRemovesCloudBytesAndClearsDurableQueue() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.seed(fixture.payload, withManifest: true)
        try await fixture.library.delete(id: fixture.payload.id)
        let deletion = try #require(try fixture.store.stage())
        try fixture.store.acknowledge(operationID: deletion.operationID, revision: 2)
        _ = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(await fixture.transport.object(fixture.payload.id) == nil)
        #expect(try fixture.store.journal()?.pendingPhotoDeletionIDs.isEmpty == true)
    }

    @Test
    func lostDeletionReceiptRetainsQueueAndIdempotentRetryFinishes() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.seed(fixture.payload, withManifest: true)
        try await fixture.library.delete(id: fixture.payload.id)
        let deletion = try #require(try fixture.store.stage())
        try fixture.store.acknowledge(operationID: deletion.operationID, revision: 2)
        await fixture.transport.loseNextDeletionReceipt()
        await #expect(throws: URLError.self) {
            try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        }
        #expect(try fixture.store.journal()?.pendingPhotoDeletionIDs == [fixture.payload.id])
        _ = try await fixture.transfer.sync(accountID: fixture.account, checking: {})
        #expect(try fixture.store.journal()?.pendingPhotoDeletionIDs.isEmpty == true)
        #expect(await fixture.transport.object(fixture.payload.id) == nil)
    }

    @Test
    func signedOutDeletionCompletionCannotWriteLocalReceipt() async throws {
        let fixture = try await makeFixture()
        await fixture.transport.seed(fixture.payload, withManifest: true)
        try await fixture.library.delete(id: fixture.payload.id)
        let deletion = try #require(try fixture.store.stage())
        try fixture.store.acknowledge(operationID: deletion.operationID, revision: 2)
        let session = PhotoTestSession()
        await fixture.transport.whenDeleted { session.active = false }
        await #expect(throws: CancellationError.self) {
            try await fixture.transfer.sync(accountID: fixture.account, checking: {
                guard session.active else { throw CancellationError() }
            })
        }
        #expect(try fixture.store.journal()?.pendingPhotoDeletionIDs == [fixture.payload.id])
    }

    private struct Fixture {
        let account: UUID
        let library: PhotographLibrary
        let store: SyncJournalStore
        let payload: SyncPhotoPayload
        let transport: PhotographTransferTransport
        let transfer: SyncPhotographTransfer
    }
}

private actor PhotographTransferTransport: SyncPhotoTransport {
    private var objects: [UUID: Data] = [:]
    private var entries: [UUID: SyncPhotoManifestEntry] = [:]
    private var loseReceipt = false
    private var loseDeletionReceipt = false
    private var deletionCallback: (@MainActor @Sendable () -> Void)?
    private(set) var uploadCount = 0
    private(set) var downloadCount = 0
    private(set) var manifestCount = 0

    func manifest(workspaceID: UUID) async throws -> [SyncPhotoManifestEntry] {
        manifestCount += 1
        return Array(entries.values)
    }
    func upload(workspaceID: UUID, payload: SyncPhotoPayload) async throws {
        uploadCount += 1
        guard objects[payload.id] == nil else { throw URLError(.cannotWriteToFile) }
        objects[payload.id] = payload.data
    }
    func download(workspaceID: UUID, photoID: UUID) async throws -> Data {
        downloadCount += 1
        guard let data = objects[photoID] else { throw URLError(.fileDoesNotExist) }
        return data
    }
    func commit(workspaceID: UUID, payload: SyncPhotoPayload) async throws -> SyncPhotoManifestEntry {
        guard objects[payload.id] == payload.data else { throw SyncTransportError.invalidResponse }
        let entry = SyncPhotoManifestEntry(id: payload.id, digest: payload.digest, byteCount: Int64(payload.data.count))
        entries[payload.id] = entry
        if loseReceipt { loseReceipt = false; throw URLError(.networkConnectionLost) }
        return entry
    }
    func seed(_ payload: SyncPhotoPayload, withManifest: Bool, corruptDigest: Bool = false) {
        objects[payload.id] = payload.data
        if withManifest {
            entries[payload.id] = .init(id: payload.id,
                digest: corruptDigest ? String(repeating: "0", count: 64) : payload.digest,
                byteCount: Int64(payload.data.count))
        }
    }
    func loseNextCommitReceipt() { loseReceipt = true }
    func loseNextDeletionReceipt() { loseDeletionReceipt = true }
    func whenDeleted(_ callback: @escaping @MainActor @Sendable () -> Void) { deletionCallback = callback }
    func delete(workspaceID: UUID, photoID: UUID) async throws {
        objects[photoID] = nil
        entries[photoID] = nil
        await deletionCallback?()
        if loseDeletionReceipt {
            loseDeletionReceipt = false
            throw URLError(.networkConnectionLost)
        }
    }
    func object(_ id: UUID) -> Data? { objects[id] }
}

@MainActor
private final class PhotoTestSession {
    var active = true
}
