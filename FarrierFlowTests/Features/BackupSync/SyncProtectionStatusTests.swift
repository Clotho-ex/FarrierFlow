import Foundation
import Testing
@testable import FarrierFlow

@Suite("Truthful cloud protection status")
struct SyncProtectionStatusTests {
    @Test
    func signInAloneCannotClaimRecordsProtected() throws {
        let record = client()
        var journal = SyncJournal(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        let initial = try SyncProtectionStatus.make(current: [record], journal: journal)
        #expect(initial.protectedRecordCount == 0)
        #expect(initial.pendingRecordCount == 1)
        #expect(!initial.isFullyProtected)
        let batch = try #require(try journal.stage([record]))
        try journal.acknowledge(operationID: batch.operationID, revision: 1)
        #expect(!(try SyncProtectionStatus.make(current: [record], journal: journal)).isFullyProtected)
        journal.lastSuccessfulSync = Date(timeIntervalSince1970: 123)
        #expect(try SyncProtectionStatus.make(current: [record], journal: journal).isFullyProtected)
    }

    @Test
    func changedAndDeletedRecordsRemainPendingAndLookalikesStayDistinct() throws {
        let first = client()
        let second = client()
        var journal = SyncJournal(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        let batch = try #require(try journal.stage([first, second]))
        try journal.acknowledge(operationID: batch.operationID, revision: 1)
        journal.lastSuccessfulSync = .now
        let edited = SyncRecord(id: first.id, kind: .client, fields: ["name": .string("Edited")])
        let status = try SyncProtectionStatus.make(current: [edited], journal: journal)
        #expect(status.recordCount == 1)
        #expect(status.protectedRecordCount == 0)
        #expect(status.pendingRecordCount == 2)
        #expect(!status.isFullyProtected)
        let original = try SyncProtectionStatus.make(current: [first, second], journal: journal)
        #expect(original.recordCount == 2)
        #expect(original.protectedRecordCount == 2)
    }

    @Test
    func photoMetadataIsNotProtectionUntilMatchingByteReceiptExists() throws {
        let photo = SyncRecord(id: UUID(), kind: .photograph, fields: ["byteCount": .integer(42)])
        var journal = SyncJournal(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        let batch = try #require(try journal.stage([photo]))
        try journal.acknowledge(operationID: batch.operationID, revision: 1)
        journal.lastSuccessfulSync = .now
        let before = try SyncProtectionStatus.make(current: [photo], journal: journal)
        #expect(before.photoCount == 1)
        #expect(before.protectedPhotoCount == 0)
        #expect(!before.isFullyProtected)
        try journal.markPhotosVerified([.init(id: photo.id, digest: String(repeating: "a", count: 64), byteCount: 42)])
        let protected = try SyncProtectionStatus.make(current: [photo], journal: journal)
        #expect(protected.protectedPhotoCount == 1)
        #expect(protected.isFullyProtected)
        let deletion = try #require(try journal.stage([]))
        try journal.acknowledge(operationID: deletion.operationID, revision: 2)
        let deleted = try SyncProtectionStatus.make(current: [], journal: journal)
        #expect(deleted.pendingPhotoDeletionCount == 1)
        #expect(!deleted.isFullyProtected)
    }

    @Test
    func ambiguousPendingOperationCannotLookSyncedAfterUserUndoesEdit() throws {
        let record = client()
        var journal = SyncJournal(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        let first = try #require(try journal.stage([record]))
        try journal.acknowledge(operationID: first.operationID, revision: 1)
        journal.lastSuccessfulSync = .now
        _ = try journal.stage([.init(id: record.id, kind: .client, fields: ["name": .string("Queued")])])
        let status = try SyncProtectionStatus.make(current: [record], journal: journal)
        #expect(status.pendingRecordCount == 1)
        #expect(!status.isFullyProtected)
    }

    private func client() -> SyncRecord {
        .init(id: UUID(), kind: .client, fields: ["name": .string("Pat")])
    }
}
