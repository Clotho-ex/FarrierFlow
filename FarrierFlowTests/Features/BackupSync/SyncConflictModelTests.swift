import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Explicit sync conflict review", .serialized)
@MainActor
struct SyncConflictModelTests {
    @Test
    func alreadyAppliedLocalDeletionStillRequiresAndCanConfirmDeferredCursor() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Before")
        context.insert(client)
        try context.save()
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let initial = try #require(try store.stage())
        try store.acknowledge(operationID: initial.operationID, revision: 1)
        try store.receive(.init(workspaceID: workspace, revision: 1, mutations: initial.mutations))
        let id = try #require(client.syncID)
        let deletion = SyncRemoteTransaction(workspaceID: workspace, revision: 2, mutations: [
            .init(id: id, kind: .client, expectedRevision: 1, record: nil)
        ])
        try store.update { $0.deferredRemote = deletion }
        context.delete(client)
        try context.save()
        let model = SyncConflictModel(container: container)
        try model.load(accountID: account)
        #expect(model.conflicts.isEmpty && !model.needsInvoiceRecovery)
        #expect(try store.journal()?.cursor == 1)
        try model.resolve([:], accountID: account)
        #expect(try store.journal()?.cursor == 2)
        #expect(try store.journal()?.deferredRemote == nil)
        #expect(try store.stage() == nil)
    }

    @Test
    func dependencyDeferralWithoutSameRecordConflictCanBeReviewedAfterLocalRepair() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Client"), barnA = Barn(name: "Barn A"), barnB = Barn(name: "Barn B")
        context.insert(client)
        context.insert(barnA)
        context.insert(barnB)
        let horse = ModelFixtures.makeHorse(client: client, barn: barnA)
        context.insert(horse)
        client.horses.append(horse)
        barnA.horses.append(horse)
        try context.save()
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let initial = try #require(try store.stage())
        try store.acknowledge(operationID: initial.operationID, revision: 1)
        try store.receive(.init(workspaceID: workspace, revision: 1, mutations: initial.mutations))
        let horseID = try #require(horse.syncID), barnBID = try #require(barnB.syncID)
        let base = try #require(try store.journal()?.baseline.first(where: { $0.id == horseID }))
        var fields = base.fields
        fields["currentBarn"] = .string(barnBID.uuidString.lowercased())
        let move = SyncRemoteTransaction(workspaceID: workspace, revision: 2, mutations: [
            .init(id: horseID, kind: .horse, expectedRevision: 1,
                record: .init(id: horseID, kind: .horse, fields: fields))
        ])
        let appointment = ModelFixtures.makeAppointment(barn: barnA, horses: [horse], in: context)
        client.notes = "Independent local note"
        try context.save()
        let before = try SyncGraphCodec.capture(in: context)
        #expect(throws: SyncJournalError.unresolvedConflicts) { try store.receive(move) }
        #expect(try store.journal()?.cursor == 1)
        #expect(try SyncGraphCodec.capture(in: context) == before)
        let model = SyncConflictModel(container: container)
        try model.load(accountID: account)
        #expect(!model.needsInvoiceRecovery)
        #expect(model.conflicts.map(\.id) == [horseID])
        #expect(throws: (any Error).self) { try model.resolve([horseID: .useCloud], accountID: account) }
        #expect(try store.journal()?.deferredRemote == move)
        #expect(try store.journal()?.cursor == 1)
        try RecordDeletionRules.delete(appointment, in: context)
        try model.load(accountID: account)
        try model.resolve([horseID: .useCloud], accountID: account)
        #expect(horse.currentBarn?.syncID == barnBID)
        #expect(client.notes == "Independent local note")
        #expect(try store.journal()?.deferredRemote == nil)
        #expect(try store.journal()?.cursor == 2)
        let next = try #require(try store.stage())
        #expect(next.mutations.count == 1 && next.mutations.first?.id == client.syncID)
    }

    @Test
    func deferredAppointmentCascadeCanUseCloudWithoutLosingUnrelatedLocalEdits() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Original client")
        let barn = Barn(name: "Stable")
        context.insert(client)
        context.insert(barn)
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        try context.save()
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let batch = try #require(try store.stage())
        try store.acknowledge(operationID: batch.operationID, revision: 1)
        try store.receive(.init(workspaceID: workspace, revision: 1, mutations: batch.mutations))
        let appointmentID = try #require(appointment.syncID)
        let membershipID = try #require(appointment.appointmentHorses.first?.syncID)
        appointment.notes = "Edited offline"
        client.notes = "Unrelated local note"
        try context.save()
        let before = try SyncGraphCodec.capture(in: context)
        let deletion = SyncRemoteTransaction(workspaceID: workspace, revision: 2, mutations: [
            .init(id: appointmentID, kind: .appointment, expectedRevision: 1, record: nil),
            .init(id: membershipID, kind: .appointmentHorse, expectedRevision: 1, record: nil)
        ])
        #expect(throws: SyncJournalError.unresolvedConflicts) { try store.receive(deletion) }
        #expect(try SyncGraphCodec.capture(in: context) == before)
        let model = SyncConflictModel(container: container)
        try model.load(accountID: account)
        #expect(model.conflicts.map(\.id) == [appointmentID])
        try model.resolve([appointmentID: .useCloud], accountID: account)
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 0)
        #expect(client.notes == "Unrelated local note")
        #expect(try store.journal()?.cursor == 2)
        #expect(try store.journal()?.deferredRemote == nil)
        #expect(try store.journal()?.conflicts.isEmpty == true)
        let next = try #require(try store.stage())
        #expect(next.mutations.count == 1 && next.mutations.first?.id == client.syncID)
        #expect(next.mutations.first?.record?.fields["notes"] == .string("Unrelated local note"))
    }

    @Test
    func choosingCloudUpdatesTheSameObjectAndKeepsIndependentLookalikes() throws {
        let fixture = try makeFixture()
        let model = SyncConflictModel(container: fixture.container)
        try model.load(accountID: fixture.account)
        #expect(model.conflicts.count == 1)
        try model.resolve([fixture.id: .useCloud], accountID: fixture.account)
        #expect(fixture.client.name == "Cloud name")
        #expect(try fixture.store.journal()?.conflicts.isEmpty == true)
        #expect(try ModelContext(fixture.container).fetchCount(FetchDescriptor<Client>()) == 2)
        #expect(try fixture.store.stage() == nil)
    }

    @Test
    func choosingIPhoneKeepsTheLatestReviewedValueAndStagesAgainstCloudRevision() throws {
        let fixture = try makeFixture()
        let model = SyncConflictModel(container: fixture.container)
        try model.load(accountID: fixture.account)
        try model.resolve([fixture.id: .keepIPhone], accountID: fixture.account)
        #expect(fixture.client.name == "iPhone name")
        let next = try #require(try fixture.store.stage())
        #expect(next.mutations.first?.expectedRevision == 2)
        #expect(next.mutations.first?.record?.fields["name"] == .string("iPhone name"))
    }

    @Test
    func changedSinceReviewAndWrongAccountCannotApplyAChoice() throws {
        let fixture = try makeFixture()
        let model = SyncConflictModel(container: fixture.container)
        try model.load(accountID: fixture.account)
        #expect(throws: SyncJournalError.accountMismatch) {
            try model.resolve([fixture.id: .useCloud], accountID: UUID())
        }
        fixture.client.name = "Saved after review opened"
        try fixture.container.mainContext.save()
        #expect(throws: SyncConflictResolutionError.changedSinceReview) {
            try model.resolve([fixture.id: .useCloud], accountID: fixture.account)
        }
        #expect(fixture.client.name == "Saved after review opened")
        #expect(try fixture.store.journal()?.conflicts.count == 1)
    }

    @Test
    func choicesMustBeCompleteAndUnsavedDraftCannotBeOverwritten() throws {
        let fixture = try makeFixture()
        let model = SyncConflictModel(container: fixture.container)
        try model.load(accountID: fixture.account)
        #expect(throws: SyncConflictResolutionError.incompleteChoices) {
            try model.resolve([:], accountID: fixture.account)
        }
        fixture.client.name = "Unsaved editor"
        #expect(throws: SyncGraphError.unsavedChanges) {
            try model.resolve([fixture.id: .useCloud], accountID: fixture.account)
        }
        #expect(fixture.client.name == "Unsaved editor")
        #expect(try fixture.store.journal()?.conflicts.count == 1)
        fixture.container.mainContext.rollback()
    }

    @Test
    func deletedCloudUUIDCannotBeResurrectedByKeepIPhone() throws {
        let fixture = try makeFixture(remoteDeletion: true)
        let model = SyncConflictModel(container: fixture.container)
        try model.load(accountID: fixture.account)
        #expect(throws: SyncConflictResolutionError.deletedIdentity) {
            try model.resolve([fixture.id: .keepIPhone], accountID: fixture.account)
        }
        #expect(try fixture.store.journal()?.conflicts.count == 1)
        try model.resolve([fixture.id: .useCloud], accountID: fixture.account)
        #expect(try ModelContext(fixture.container).fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try fixture.store.journal()?.conflicts.isEmpty == true)
    }

    private func makeFixture(remoteDeletion: Bool = false) throws -> Fixture {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Original")
        let lookalike = Client(name: "Cloud name")
        container.mainContext.insert(client)
        container.mainContext.insert(lookalike)
        try container.mainContext.save()
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let initial = try #require(try store.stage())
        try store.acknowledge(operationID: initial.operationID, revision: 1)
        try store.receive(.init(workspaceID: workspace, revision: 1, mutations: initial.mutations))
        let id = try #require(client.syncID)
        let original = try #require(try store.journal()?.baseline.first { $0.id == id })
        var fields = original.fields
        fields["name"] = .string("Cloud name")
        let remote = SyncRecord(id: id, kind: .client, fields: fields)
        client.name = "iPhone name"
        try container.mainContext.save()
        try store.receive(.init(workspaceID: workspace, revision: 2, mutations: [
            .init(id: id, kind: .client, expectedRevision: 1, record: remoteDeletion ? nil : remote)
        ]))
        return .init(container: container, store: store, client: client, id: id, account: account)
    }

    private struct Fixture {
        let container: ModelContainer
        let store: SyncJournalStore
        let client: Client
        let id: UUID
        let account: UUID
    }
}
