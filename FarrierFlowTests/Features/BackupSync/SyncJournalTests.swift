import Foundation
import Testing
@testable import FarrierFlow

@Suite("Durable sync journal")
struct SyncJournalTests {
    @Test
    func legacyPendingContractSurvivesUpgradeWithoutChangingBatch() throws {
        var journal = makeJournal()
        let batch = try #require(try journal.stage([record("Before")]))
        #expect(journal.pendingProtocol == .deletion)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(journal)) as? [String: Any])
        json.removeValue(forKey: "pendingProtocolVersion")
        var legacy = try JSONDecoder().decode(SyncJournal.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.pendingProtocol == .legacy)
        #expect(try legacy.stage([record("After")]) == batch)
        #expect(legacy.pendingProtocol == .legacy)
        try legacy.acknowledge(operationID: batch.operationID, revision: 1)
        _ = try legacy.stage([record("After")])
        #expect(legacy.pendingProtocol == .deletion)
    }
    private let recordID = UUID()
    private let accountID = UUID()
    private let workspaceID = UUID()

    @Test
    func retriedBatchSurvivesRelaunchWithoutChangingOperationIdentity() throws {
        var journal = makeJournal()
        let staged = try journal.stage([record("Before")])
        let first = try #require(staged)
        let encoded = try JSONEncoder().encode(journal)
        var reopened = try JSONDecoder().decode(SyncJournal.self, from: encoded)
        let stagedRetry = try reopened.stage([record("After")])
        let retried = try #require(stagedRetry)
        #expect(retried == first)
        #expect(retried.mutations.first?.record?.fields["name"] == .string("Before"))
    }

    @Test
    func acknowledgmentRetainsEditsMadeDuringUpload() throws {
        var journal = makeJournal()
        let staged = try journal.stage([record("Before")])
        let first = try #require(staged)
        try journal.acknowledge(operationID: first.operationID, revision: 7)
        let restaged = try journal.stage([record("After")])
        let second = try #require(restaged)
        #expect(second.operationID != first.operationID)
        #expect(second.mutations.first?.expectedRevision == 7)
        #expect(second.mutations.first?.record?.fields["name"] == .string("After"))
    }

    @Test
    func deletionOfPreviouslyProtectedRecordBecomesDurableTombstone() throws {
        var journal = makeJournal()
        let staged = try journal.stage([record("Before")])
        let first = try #require(staged)
        try journal.acknowledge(operationID: first.operationID, revision: 3)
        let stagedDeletion = try journal.stage([])
        let deletion = try #require(stagedDeletion)
        #expect(deletion.mutations.count == 1)
        #expect(deletion.mutations.first?.id == recordID)
        #expect(deletion.mutations.first?.record == nil)
        #expect(deletion.mutations.first?.expectedRevision == 3)
        var reopened = try JSONDecoder().decode(
            SyncJournal.self, from: JSONEncoder().encode(journal)
        )
        let retry = try reopened.stage([])
        #expect(retry == deletion)
    }

    @Test
    func repeatedAcknowledgmentCannotAcknowledgeADifferentPendingOperation() throws {
        var journal = makeJournal()
        let staged = try journal.stage([record("Before")])
        let first = try #require(staged)
        try journal.acknowledge(operationID: first.operationID, revision: 1)
        let restaged = try journal.stage([record("After")])
        let second = try #require(restaged)
        #expect(throws: SyncJournalError.unexpectedAcknowledgment) {
            try journal.acknowledge(operationID: first.operationID, revision: 1)
        }
        #expect(journal.pending == second)
    }

    @Test
    func differentAccountCannotAdoptAnExistingJournal() {
        let journal = makeJournal()
        #expect(throws: SyncJournalError.accountMismatch) {
            try journal.verifyBinding(accountID: UUID(), workspaceID: workspaceID)
        }
    }

    @Test
    func duplicateIdentityIsRejectedEvenWithDifferentNames() {
        var journal = makeJournal()
        #expect(throws: SyncJournalError.duplicateIdentity(recordID)) {
            try journal.stage([record("First"), record("Second")])
        }
        #expect(journal.pending == nil)
    }

    @Test
    func acknowledgedDeletionDoesNotRegenerateOnNextRetry() throws {
        var journal = makeJournal()
        let staged = try journal.stage([record("Before")])
        let first = try #require(staged)
        try journal.acknowledge(operationID: first.operationID, revision: 2)
        let stagedDeletion = try journal.stage([])
        let deletion = try #require(stagedDeletion)
        try journal.acknowledge(operationID: deletion.operationID, revision: 4)
        let next = try journal.stage([])
        #expect(next == nil)
    }

    @Test
    func largeHistoryUploadsInBoundedBatchesWithoutDroppingAnyIdentities() throws {
        let records = (0..<10_001).map { index in
            SyncRecord(id: UUID(), kind: .client, fields: ["name": .string("Client \(index)")])
        }
        var journal = makeJournal()
        var uploaded = Set<UUID>()
        var revision: Int64 = 0
        while let batch = try journal.stage(records) {
            #expect(batch.mutations.count <= 200)
            #expect(uploaded.isDisjoint(with: batch.mutations.map(\.id)))
            uploaded.formUnion(batch.mutations.map(\.id))
            revision += 1
            try journal.acknowledge(operationID: batch.operationID, revision: revision)
        }
        #expect(uploaded.count == 10_001)
        #expect(journal.baseline.count == 10_001)
    }

    @Test
    func dependentInvoiceGraphStaysInOneBatchEvenAcrossTheSoftLimit() throws {
        let profile = SyncRecord(
            id: UUID(), kind: .businessProfile,
            fields: ["name": .string("Business"), "nextInvoiceNumber": .integer(2)]
        )
        let client = SyncRecord(id: UUID(), kind: .client, fields: ["name": .string("Pat")])
        let invoice = SyncRecord(
            id: UUID(), kind: .invoice,
            fields: ["number": .integer(1), "client": .string(client.id.uuidString.lowercased())]
        )
        let group = SyncRecord(
            id: UUID(), kind: .invoiceVisit,
            fields: ["invoice": .string(invoice.id.uuidString.lowercased())]
        )
        let lines = (0..<220).map { _ in
            SyncRecord(id: UUID(), kind: .invoiceLineItem,
                       fields: ["invoiceVisit": .string(group.id.uuidString.lowercased())])
        }
        let records = [profile, client, invoice, group] + lines
        var journal = makeJournal()
        var revision: Int64 = 0
        var foundInvoice = false
        while let batch = try journal.stage(records) {
            if batch.mutations.contains(where: { $0.id == invoice.id }) {
                foundInvoice = true
                #expect(batch.mutations.contains(where: { $0.id == group.id }))
                #expect(Set(batch.mutations.map(\.id)).isSuperset(of: lines.map(\.id)))
            }
            revision += 1
            try journal.acknowledge(operationID: batch.operationID, revision: revision)
        }
        #expect(foundInvoice)
    }

    private func makeJournal() -> SyncJournal {
        SyncJournal(accountID: accountID, workspaceID: workspaceID, deviceID: UUID())
    }

    @Test
    func photoCleanupIsQueuedOnlyAfterMetadataDeletionAcknowledgmentAndSurvivesRelaunch() throws {
        var journal = makeJournal()
        let photo = SyncRecord(id: recordID, kind: .photograph, fields: ["byteCount": .integer(42)])
        let upload = try #require(try journal.stage([photo]))
        try journal.acknowledge(operationID: upload.operationID, revision: 1)
        let deletion = try #require(try journal.stage([]))
        #expect(journal.pendingPhotoDeletionIDs.isEmpty)
        try journal.acknowledge(operationID: deletion.operationID, revision: 2)
        var reopened = try JSONDecoder().decode(SyncJournal.self, from: JSONEncoder().encode(journal))
        #expect(reopened.pendingPhotoDeletionIDs == [recordID])
        try reopened.confirmPhotoDeletion(id: recordID)
        #expect(reopened.pendingPhotoDeletionIDs.isEmpty)
        #expect(reopened.revisions[recordID] == 2)
    }

    @Test
    func remotePhotoTombstoneQueuesCleanupWithoutDuplicatingRetry() throws {
        var journal = makeJournal()
        let photo = SyncRecord(id: recordID, kind: .photograph, fields: ["byteCount": .integer(42)])
        _ = try journal.receive(.init(workspaceID: workspaceID, revision: 1,
            mutations: [.init(id: recordID, kind: .photograph, expectedRevision: 0, record: photo)]), current: [])
        let deletion = SyncRemoteTransaction(workspaceID: workspaceID, revision: 2,
            mutations: [.init(id: recordID, kind: .photograph, expectedRevision: 1, record: nil)])
        _ = try journal.receive(deletion, current: [photo])
        _ = try journal.receive(deletion, current: [])
        #expect(journal.pendingPhotoDeletionIDs == [recordID])
    }

    @Test
    func cleanupReceiptCannotClearAnAliveOrUnqueuedPhoto() throws {
        var journal = makeJournal()
        let photo = SyncRecord(id: recordID, kind: .photograph, fields: ["byteCount": .integer(42)])
        let upload = try #require(try journal.stage([photo]))
        try journal.acknowledge(operationID: upload.operationID, revision: 1)
        #expect(throws: SyncJournalError.unexpectedAcknowledgment) {
            try journal.confirmPhotoDeletion(id: recordID)
        }
        #expect(journal.baseline == [photo])
    }

    private func record(_ name: String) -> SyncRecord {
        SyncRecord(id: recordID, kind: .client, fields: ["name": .string(name)])
    }
}
