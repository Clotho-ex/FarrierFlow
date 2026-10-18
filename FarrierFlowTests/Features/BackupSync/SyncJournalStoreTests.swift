import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Sync journal persistence", .serialized)
@MainActor
struct SyncJournalStoreTests {
    @Test
    func committedChangesAndExactPendingBatchSurviveStoreReopening() throws {
        let url = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Journal-")
            .appending(path: "FarrierFlow.store")
        let account = UUID()
        let workspace = UUID()
        let clientID = UUID()
        let first = try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            let context = ModelContext(container)
            context.insert(Client(syncID: clientID, name: "Before"))
            try context.save()
            let store = SyncJournalStore(container: container)
            try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
            let staged = try store.stage()
            let batch = try #require(staged)
            let client = try #require(context.fetch(FetchDescriptor<Client>()).first)
            client.name = "After"
            try context.save()
            return batch
        }
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            let store = SyncJournalStore(container: container)
            try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
            let retry = try store.stage()
            #expect(retry == first)
            try store.acknowledge(operationID: first.operationID, revision: 8)
            let staged = try store.stage()
            let next = try #require(staged)
            #expect(next.mutations.first?.expectedRevision == 8)
            #expect(next.mutations.first?.record?.fields["name"] == .string("After"))
        }
    }

    @Test
    func committedCascadeDeletionIsDetectedAfterRelaunch() throws {
        let url = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Cascade-")
            .appending(path: "FarrierFlow.store")
        let account = UUID()
        let workspace = UUID()
        let deletedIDs = try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            try PreviewFixtures.seed(container.mainContext)
            let store = SyncJournalStore(container: container)
            try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
            let staged = try store.stage()
            let batch = try #require(staged)
            try store.acknowledge(operationID: batch.operationID, revision: 1)
            let appointment = try #require(
                container.mainContext.fetch(FetchDescriptor<Appointment>()).first
            )
            let join = try #require(appointment.appointmentHorses.first)
            let ids = Set(try SyncRecordIdentity.requireIDs([appointment]))
                .union(try SyncRecordIdentity.requireIDs([join]))
            try RecordDeletionRules.delete(appointment, in: container.mainContext)
            return ids
        }
        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            let staged = try SyncJournalStore(container: container).stage()
            let batch = try #require(staged)
            #expect(Set(batch.mutations.filter { $0.record == nil }.map(\.id)) == deletedIDs)
        }
    }

    @Test
    func anotherAppleAccountCannotRebindProtectedLocalRecords() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        #expect(throws: SyncJournalError.accountMismatch) {
            try store.bind(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        }
    }

    @Test
    func restoredPhoneGetsItsOwnDeviceIdentityWithoutLosingPendingBatch() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let store = SyncJournalStore(container: container)
        let account = UUID()
        let workspace = UUID()
        let oldDevice = UUID()
        let replacementDevice = UUID()
        try store.bind(accountID: account, workspaceID: workspace, deviceID: oldDevice)
        container.mainContext.insert(Client(name: "Protected history"))
        try container.mainContext.save()
        let pending = try store.stage()
        try store.bind(accountID: account, workspaceID: workspace, deviceID: replacementDevice)
        #expect(try store.journal()?.deviceID == replacementDevice)
        #expect(try store.stage() == pending)
        #expect(pending?.deviceID == oldDevice)
    }

    @Test
    func unsavedEditorChangesAreNotUploadedByIndependentSyncContext() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        container.mainContext.insert(Client(name: "Draft"))
        #expect(try store.stage() == nil)
        container.mainContext.rollback()
    }
}
