import Foundation
import Supabase
import Testing
@testable import FarrierFlow

@Suite("Device-held cloud deletion receipts", .serialized)
struct CloudDeletionReceiptStoreTests {
    @Test
    func intentSurvivesReopenAndCannotBeReplacedByAnotherAccountOrWorkspace() throws {
        let storage = SyncTestAuthStorage()
        let receipts = CloudDeletionReceiptStore(storage: storage)
        let intent = try receipts.prepare(accountID: UUID(), workspaceID: UUID())
        #expect(intent.receiptToken.utf8.count == 43)
        let reopened = CloudDeletionReceiptStore(storage: storage)
        #expect(try reopened.prepare(accountID: intent.accountID, workspaceID: intent.workspaceID) == intent)
        #expect(throws: SyncJournalError.accountMismatch) { try reopened.prepare(accountID: UUID(), workspaceID: intent.workspaceID) }
        #expect(throws: SyncJournalError.accountMismatch) { try reopened.prepare(accountID: intent.accountID, workspaceID: UUID()) }
        #expect(try reopened.load() == intent)
    }

    @Test
    func anAmbiguousSentRequestCannotBeCancelledAndReceiptPhaseNeverRegresses() throws {
        let receipts = CloudDeletionReceiptStore(storage: SyncTestAuthStorage())
        let intent = try receipts.prepare(accountID: UUID(), workspaceID: UUID())
        try receipts.advance(intent, to: .sent)
        #expect(throws: CloudDeletionError.requestMayHaveBeenSent) { try receipts.cancelPrepared(intent) }
        try receipts.advance(intent, to: .queued)
        #expect(throws: CloudDeletionError.invalidPhase) { try receipts.advance(intent, to: .prepared) }
        #expect(try receipts.load()?.phase == .queued)
    }

    @Test
    func beforeAnyRequestIsSentCancellationRemovesOnlyThePreparedReceipt() throws {
        let storage = SyncTestAuthStorage()
        try storage.store(key: "unrelated", value: Data("keep".utf8))
        let receipts = CloudDeletionReceiptStore(storage: storage)
        let intent = try receipts.prepare(accountID: UUID(), workspaceID: UUID())
        try receipts.cancelPrepared(intent)
        #expect(try receipts.load() == nil)
        #expect(try storage.retrieve(key: "unrelated") == Data("keep".utf8))
    }

    @Test
    func actualReceiptKeychainStorageIsDeviceBoundAndReopens() throws {
        let storage = SyncSessionKeychainStorage(service: "FarrierFlow.Deletion.Tests." + UUID().uuidString)
        defer { try? storage.remove(key: CloudDeletionReceiptStore.storageKey) }
        let receipts = CloudDeletionReceiptStore(storage: storage)
        let intent = try receipts.prepare(accountID: UUID(), workspaceID: UUID())
        #expect(try CloudDeletionReceiptStore(storage: storage).load() == intent)
    }
}
