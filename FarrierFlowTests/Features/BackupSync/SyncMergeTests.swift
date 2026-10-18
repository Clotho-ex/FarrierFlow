import Foundation
import Testing
@testable import FarrierFlow

@Suite("UUID based sync merging")
struct SyncMergeTests {
    @Test
    func disjointEditsToSameUUIDMergeWithoutLosingEitherField() {
        let id = UUID()
        let base = client(id, name: "Pat", notes: "Old")
        let local = client(id, name: "Pat", notes: "New notes")
        let remote = client(id, name: "Patrick", notes: "Old")
        #expect(SyncRecordMerge.merge(base: base, local: local, remote: remote) ==
                .merged(client(id, name: "Patrick", notes: "New notes")))
    }

    @Test
    func twoDifferentEditsToSameFieldRequireReview() {
        let id = UUID()
        #expect(SyncRecordMerge.merge(
            base: client(id, name: "Pat"), local: client(id, name: "Local"),
            remote: client(id, name: "Cloud")
        ) == .conflict)
    }

    @Test
    func deletionDoesNotEraseAnUnseenEdit() {
        let id = UUID()
        #expect(SyncRecordMerge.merge(
            base: client(id, name: "Pat"), local: nil,
            remote: client(id, name: "Patrick")
        ) == .conflict)
        #expect(SyncRecordMerge.merge(
            base: client(id, name: "Pat"), local: client(id, name: "Patrick"),
            remote: nil
        ) == .conflict)
    }

    @Test
    func lookalikesWithDifferentUUIDsAreNeverCollapsed() {
        let base = client(UUID(), name: "Pat")
        let lookalike = client(UUID(), name: "Pat")
        #expect(SyncRecordMerge.merge(
            base: base, local: base, remote: lookalike
        ) == .conflict)
    }

    @Test
    func equalEditsAndUncontestedDeletionNeedNoReview() {
        let id = UUID()
        let base = client(id, name: "Pat")
        let edit = client(id, name: "Patrick")
        #expect(SyncRecordMerge.merge(base: base, local: edit, remote: edit) == .merged(edit))
        #expect(SyncRecordMerge.merge(base: base, local: base, remote: nil) == .merged(nil))
    }

    @Test
    func remoteCommitIsIdempotentAndNewLocalEditUsesLatestRevision() throws {
        let account = UUID()
        let workspace = UUID()
        let id = UUID()
        var journal = SyncJournal(accountID: account, workspaceID: workspace, deviceID: UUID())
        let transaction = SyncRemoteTransaction(
            workspaceID: workspace, revision: 1,
            mutations: [.init(id: id, kind: .client, expectedRevision: 0,
                              record: client(id, name: "Cloud"))]
        )
        let received = try journal.receive(transaction, current: [])
        #expect(received == [client(id, name: "Cloud")])
        #expect(journal.cursor == 1)
        let replayed = try journal.receive(transaction, current: received)
        #expect(replayed == received)
        let staged = try journal.stage([client(id, name: "Edited")])
        let batch = try #require(staged)
        #expect(batch.mutations.first?.expectedRevision == 1)
    }

    @Test
    func skippedCursorOrDifferentWorkspaceCannotAdvanceJournal() {
        let workspace = UUID()
        var journal = SyncJournal(accountID: UUID(), workspaceID: workspace, deviceID: UUID())
        #expect(throws: SyncJournalError.invalidCursor) {
            try journal.receive(
                .init(workspaceID: workspace, revision: 2, mutations: []), current: []
            )
        }
        #expect(journal.cursor == 0)
        #expect(throws: SyncJournalError.accountMismatch) {
            try journal.receive(
                .init(workspaceID: UUID(), revision: 1, mutations: []), current: []
            )
        }
    }

    @Test
    func unresolvedConflictIsDurableAndBlocksUploads() throws {
        let workspace = UUID()
        let id = UUID()
        var journal = SyncJournal(accountID: UUID(), workspaceID: workspace, deviceID: UUID())
        let initial = SyncRemoteTransaction(
            workspaceID: workspace, revision: 1,
            mutations: [.init(id: id, kind: .client, expectedRevision: 0,
                              record: client(id, name: "Pat"))]
        )
        _ = try journal.receive(initial, current: [])
        let changed = SyncRemoteTransaction(
            workspaceID: workspace, revision: 2,
            mutations: [.init(id: id, kind: .client, expectedRevision: 1,
                              record: client(id, name: "Cloud"))]
        )
        let local = client(id, name: "Local")
        let received = try journal.receive(changed, current: [local])
        #expect(received == [local])
        #expect(journal.conflicts.first?.local == local)
        #expect(journal.conflicts.first?.remote == client(id, name: "Cloud"))
        var reopened = try JSONDecoder().decode(
            SyncJournal.self, from: JSONEncoder().encode(journal)
        )
        #expect(throws: SyncJournalError.unresolvedConflicts) {
            try reopened.stage([local])
        }
    }

    @Test
    func malformedRemoteRevisionAndKindCannotCorruptAcknowledgedIdentity() throws {
        let workspace = UUID()
        let id = UUID()
        var journal = SyncJournal(accountID: UUID(), workspaceID: workspace, deviceID: UUID())
        let record = client(id, name: "Pat")
        _ = try journal.receive(.init(
            workspaceID: workspace, revision: 1,
            mutations: [.init(id: id, kind: .client, expectedRevision: 0, record: record)]
        ), current: [])
        let before = journal
        let otherKind = SyncRecord(id: id, kind: .barn, fields: record.fields)
        #expect(throws: SyncJournalError.invalidMutation) {
            try journal.receive(.init(
                workspaceID: workspace, revision: 2,
                mutations: [.init(id: id, kind: .barn, expectedRevision: 1, record: otherKind)]
            ), current: [record])
        }
        #expect(journal == before)
        #expect(throws: SyncJournalError.invalidMutation) {
            try journal.receive(.init(
                workspaceID: workspace, revision: 2,
                mutations: [.init(id: id, kind: .client, expectedRevision: 2, record: record)]
            ), current: [record])
        }
        #expect(journal == before)
    }

    @Test
    func nonpositiveCommitIsRejectedRatherThanMistakenForReplay() {
        let workspace = UUID()
        var journal = SyncJournal(accountID: UUID(), workspaceID: workspace, deviceID: UUID())
        #expect(throws: SyncJournalError.invalidCursor) {
            try journal.receive(.init(
                workspaceID: workspace, revision: 0, mutations: []
            ), current: [])
        }
    }

    private func client(_ id: UUID, name: String, notes: String = "") -> SyncRecord {
        .init(id: id, kind: .client, fields: ["name": .string(name), "notes": .string(notes)])
    }
}
