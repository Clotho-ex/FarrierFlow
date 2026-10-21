import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Sync data safety regressions", .serialized)
@MainActor
struct SyncDataSafetyTests {
    @Test
    func savingAnOpenClientDraftMustNotRevertAnUntouchedRemotePhone() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Original", phone: "111")
        context.insert(client)
        try context.save()
        let store = SyncJournalStore(container: container)
        let account = UUID(), workspace = UUID()
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let initial = try #require(try store.stage())
        try store.acknowledge(operationID: initial.operationID, revision: 1)
        try store.receive(.init(workspaceID: workspace, revision: 1, mutations: initial.mutations))
        let editor = ClientEditorModel(client: client)
        editor.draft.notes = "Only field edited in this form"
        #expect(!context.hasChanges)
        let id = try #require(client.syncID)
        var fields = try #require(try store.journal()?.baseline.first { $0.id == id }).fields
        fields["phone"] = .string("222")
        try store.receive(.init(workspaceID: workspace, revision: 2, mutations: [
            .init(id: id, kind: .client, expectedRevision: 1, record: .init(id: id, kind: .client, fields: fields))
        ]))
        #expect(client.phone == "222")
        _ = try #require(editor.save(in: context))
        let pending = try #require(try store.stage())
        #expect(pending.mutations.first?.record?.fields["phone"] == .string("222"))
        #expect(client.phone == "222")
        #expect(client.notes == "Only field edited in this form")
    }

    @Test
    func invoiceRecoveryMustNotResolveAnUnreviewedClientConflict() throws {
        let f = try InvoiceActionGraph.make()
        let original = try SyncGraphCodec.capture(in: f.context)
        let client = try #require(f.context.fetch(FetchDescriptor<Client>()).first)
        let clientID = try #require(client.syncID)
        let account = UUID(), workspace = UUID(), device = UUID()
        var journal = SyncJournal(accountID: account, workspaceID: workspace, deviceID: device)
        journal.invoicingDeviceID = device
        journal.invoicingGeneration = 1
        let financial: Set<SyncRecordKind> = [.invoice, .invoiceVisit, .invoiceLineItem, .payment]
        let operational = original.filter { !financial.contains($0.kind) }
        _ = try journal.receive(.init(workspaceID: workspace, revision: 1, mutations: operational.map {
            .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0)
        }), current: original)
        client.name = "Unreviewed local name"
        try f.context.save()
        let current = try SyncGraphCodec.capture(in: f.context)
        var cloudClientFields = try #require(operational.first { $0.id == clientID }).fields
        cloudClientFields["name"] = .string("Unreviewed cloud name")
        let cloudClient = SyncRecord(id: clientID, kind: .client, fields: cloudClientFields)
        _ = try journal.receive(.init(workspaceID: workspace, revision: 2, mutations: [
            .init(id: clientID, kind: .client, expectedRevision: 1, record: cloudClient)
        ]), current: current)
        #expect(journal.conflicts.count == 1)
        let store = SyncJournalStore(container: f.container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: device)
        try store.update { $0 = journal }
        let replacement = Dictionary(uniqueKeysWithValues: original.filter { financial.contains($0.kind) }.map { ($0.id, UUID()) })
        let cloudFinancial = try original.filter { financial.contains($0.kind) }.map { record in
            var fields = record.fields
            for (key, value) in fields {
                if case .string(let text) = value, let id = UUID(uuidString: text), let changed = replacement[id] {
                    fields[key] = .string(changed.uuidString.lowercased())
                }
            }
            return SyncRecord(id: try #require(replacement[record.id]), kind: record.kind, fields: fields)
        }
        let transaction = SyncRemoteTransaction(workspaceID: workspace, revision: 3, mutations: cloudFinancial.map {
            .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0)
        })
        #expect(throws: SyncJournalError.unresolvedConflicts) { try store.receive(transaction) }
        let conflictModel = SyncConflictModel(container: f.container)
        try conflictModel.load(accountID: account)
        #expect(conflictModel.needsInvoiceRecovery)
        let updatedJournal = try #require(try store.journal())
        let cloudRecords = updatedJournal.baseline + cloudFinancial
        var revisions = updatedJournal.revisions
        for record in cloudFinancial { revisions[record.id] = 3 }
        let cloud = SyncRecoveryCloudSnapshot(workspaceID: workspace, revision: 3, records: cloudRecords,
            revisions: revisions, invoicingDeviceID: UUID(), invoicingGeneration: 2)
        let review = try SyncInvoiceRecoveryReview.make(current: current, journal: updatedJournal, cloud: cloud, capturedAt: Date())
        try store.applyRecovery(review, settings: .useCloud)
        let latest = try #require(try store.journal())
        #expect(latest.conflicts.count == 1)
        #expect(throws: SyncJournalError.unresolvedConflicts) { try store.stage() }
        var newest = cloudClient.fields
        newest["name"] = .string("Newest cloud name")
        try store.receive(.init(workspaceID: workspace, revision: 4, mutations: [
            .init(id: clientID, kind: .client, expectedRevision: 2,
                  record: .init(id: clientID, kind: .client, fields: newest))
        ]))
        #expect(try ModelContext(f.container).fetch(FetchDescriptor<Client>()).first?.name == "Unreviewed local name")
        let reviewModel = SyncConflictModel(container: f.container)
        try reviewModel.load(accountID: account)
        #expect(reviewModel.conflicts.first?.local?.fields["name"] == .string("Unreviewed local name"))
        #expect(reviewModel.conflicts.first?.remote?.fields["name"] == .string("Newest cloud name"))
        try reviewModel.resolve([clientID: .useCloud], accountID: account)
        #expect(try store.journal()?.conflicts.isEmpty == true)
    }

    @Test
    func recoveryMustQueueCloudPhotoCleanupWhenItConsumesATombstone() throws {
        let f = try InvoiceActionGraph.make()
        let member = try #require(f.context.fetch(FetchDescriptor<VisitHorse>()).first)
        let photoID = UUID()
        let photo = Photograph(id: photoID, createdAt: Date(), pixelWidth: 10, pixelHeight: 10,
                               byteCount: 10, visitHorse: member)
        f.context.insert(photo)
        member.photographs.append(photo)
        try DomainGraphValidator.save(f.context)
        let current = try SyncGraphCodec.capture(in: f.context)
        let financial: Set<SyncRecordKind> = [.invoice, .invoiceVisit, .invoiceLineItem, .payment]
        let operational = current.filter { !financial.contains($0.kind) }
        let account = UUID(), workspace = UUID(), device = UUID()
        var journal = SyncJournal(accountID: account, workspaceID: workspace, deviceID: device)
        journal.invoicingDeviceID = device
        journal.invoicingGeneration = 1
        _ = try journal.receive(.init(workspaceID: workspace, revision: 1, mutations: operational.map {
            .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0)
        }), current: current)
        try journal.markPhotosVerified([.init(id: photoID, digest: String(repeating: "a", count: 64), byteCount: 10)])
        let store = SyncJournalStore(container: f.container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: device)
        try store.update { $0 = journal }
        let pending = try #require(try store.stage())
        try store.recordConfirmedRejection(operationID: pending.operationID, reason: .invoicingAuthority)
        let latest = try #require(try store.journal())
        var revisions = latest.revisions
        revisions[photoID] = 2
        let cloud = SyncRecoveryCloudSnapshot(workspaceID: workspace, revision: 2,
            records: latest.baseline.filter { $0.id != photoID }, revisions: revisions,
            invoicingDeviceID: UUID(), invoicingGeneration: 2)
        let review = try SyncInvoiceRecoveryReview.make(current: current, journal: latest, cloud: cloud, capturedAt: Date())
        try store.applyRecovery(review, settings: .useCloud)
        let recovered = try #require(try store.journal())
        #expect(try ModelContext(f.container).fetchCount(FetchDescriptor<Photograph>()) == 0)
        #expect(recovered.pendingPhotoDeletionIDs.contains(photoID))
        #expect(!recovered.verifiedPhotoReceipts.contains { $0.id == photoID })
    }

}
