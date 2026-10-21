import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Reviewed invoice history recovery", .serialized)
@MainActor
struct SyncInvoiceRecoveryTests {
    @Test(arguments: [false, true])
    func persistentRecoveryIsAtomicOnSaveFailureAndSurvivesReopen(readOnly: Bool) throws {
        let f = try fixture(status: .paid)
        let journal = try #require(try f.store.journal())
        let directory = FileManager.default.temporaryDirectory.appending(path: "Recovery-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "business.store")
        try autoreleasepool {
            let disk = try ModelContainerFactory.persistentStoreTest(at: url)
            try SyncGraphCodec.apply(f.original, in: disk.mainContext)
            try SyncJournalStore(container: disk).bind(accountID: journal.accountID,
                workspaceID: journal.workspaceID, deviceID: journal.deviceID)
            try SyncJournalStore.write(journal, in: disk.mainContext)
            try disk.mainContext.save()
        }
        var expectedArchive: InvoiceHistoryArchive?
        try autoreleasepool {
            let schema = Schema(versionedSchema: FarrierFlowSchemaV5.self)
            let config = ModelConfiguration(schema: schema, url: url, allowsSave: !readOnly, cloudKitDatabase: .none)
            let disk = try ModelContainer(for: schema, migrationPlan: FarrierFlowMigrationPlan.self, configurations: [config])
            let store = SyncJournalStore(container: disk)
            let review = try SyncInvoiceRecoveryReview.make(current: f.original,
                journal: #require(try store.journal()), cloud: f.cloud, capturedAt: Date())
            if readOnly {
                #expect(throws: (any Error).self) { try store.applyRecovery(review, settings: .useCloud) }
                #expect(!disk.mainContext.hasChanges)
                #expect(try SyncGraphCodec.capture(in: ModelContext(disk)) == f.original)
                #expect(try store.journal() == journal)
            } else {
                try store.applyRecovery(review, settings: .useCloud)
                expectedArchive = review.archive
            }
        }
        for _ in 0..<2 {
            try autoreleasepool {
                let disk = try ModelContainerFactory.persistentStoreTest(at: url)
                let store = SyncJournalStore(container: disk)
                if readOnly { #expect(try store.journal() == journal) }
                else {
                    #expect(try store.journal()?.invoiceHistoryArchives == [#require(expectedArchive)])
                    #expect(try ModelContext(disk).fetch(FetchDescriptor<WorkItem>())
                        .first(where: { $0.syncID == f.localWorkID })?.billingHoldID == f.localInvoiceID)
                    #expect(try InvoiceHistoryArchiveReader(container: disk)
                        .content(archiveID: #require(expectedArchive).id, invoiceID: f.localInvoiceID).status == .paid)
                }
            }
        }
    }

    @Test
    func sameSourceCloudInvoiceSurvivesWhileExactWorkIsHeld() throws {
        let f = try fixture(status: .unpaid)
        let journal = try #require(try f.store.journal())
        let replacement = Dictionary(uniqueKeysWithValues: f.original.filter {
            [.invoice, .invoiceVisit, .invoiceLineItem].contains($0.kind)
        }.map { ($0.id, UUID()) })
        let records = f.original.map { record in
            var fields = record.fields
            for (key, value) in fields {
                if case .string(let text) = value, let id = UUID(uuidString: text), let changed = replacement[id] {
                    fields[key] = .string(changed.uuidString.lowercased())
                }
            }
            if record.kind == .invoice { fields["number"] = .integer(2) }
            if record.kind == .businessProfile { fields["nextInvoiceNumber"] = .integer(3) }
            return SyncRecord(id: replacement[record.id] ?? record.id, kind: record.kind, fields: fields)
        }
        let cloud = SyncRecoveryCloudSnapshot(workspaceID: journal.workspaceID, revision: 1,
            records: records, revisions: Dictionary(uniqueKeysWithValues: records.map { ($0.id, Int64(1)) }),
            invoicingDeviceID: journal.deviceID, invoicingGeneration: 1)
        let review = try SyncInvoiceRecoveryReview.make(current: f.original, journal: journal,
            cloud: cloud, capturedAt: Date())
        try f.store.applyRecovery(review, settings: .keepLocal)
        let context = ModelContext(f.local.container)
        let invoice = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
        #expect(invoice.number == 2 && invoice.syncID == replacement[f.localInvoiceID])
        let work = try #require(context.fetch(FetchDescriptor<WorkItem>()).first)
        #expect(work.billingHoldID == f.localInvoiceID)
        let client = try #require(context.fetch(FetchDescriptor<Client>()).first)
        #expect(try InvoiceEligibilityRules.choices(for: client.persistentModelID, in: context).isEmpty)
    }

    @Test
    func profileOnlyRecoveryPreservesPrimaryOfflineSequenceAndUsesCanonicalID() throws {
        let local = try ModelContainerFactory.inMemoryTest()
        local.mainContext.insert(BusinessProfile(name: "Local", nextInvoiceNumber: 9, currencyCode: "GBP"))
        try local.mainContext.save()
        let store = SyncJournalStore(container: local)
        let device = UUID(), workspace = UUID()
        try store.bind(accountID: UUID(), workspaceID: workspace, deviceID: device)
        try store.update { $0.invoicingDeviceID = device; $0.invoicingGeneration = 1 }
        let remote = try ModelContainerFactory.inMemoryTest()
        remote.mainContext.insert(BusinessProfile(name: "Cloud", nextInvoiceNumber: 3, currencyCode: "GBP"))
        try remote.mainContext.save()
        let graph = try SyncGraphCodec.capture(in: remote.mainContext)
        let cloud = SyncRecoveryCloudSnapshot(workspaceID: workspace, revision: 1, records: graph,
            revisions: Dictionary(uniqueKeysWithValues: graph.map { ($0.id, Int64(1)) }),
            invoicingDeviceID: device, invoicingGeneration: 1)
        let review = try SyncInvoiceRecoveryReview.make(current: SyncGraphCodec.capture(in: local.mainContext),
            journal: #require(try store.journal()), cloud: cloud, capturedAt: Date())
        #expect(review.archive == nil)
        try store.applyRecovery(review, settings: .keepLocal)
        let profile = try #require(ModelContext(local).fetch(FetchDescriptor<BusinessProfile>()).first)
        #expect(profile.name == "Local" && profile.nextInvoiceNumber == 9 && profile.syncID == graph.first?.id)
    }

    @Test
    func cloudChangeAfterReviewPreventsConfirmation() async throws {
        let f = try fixture(status: .unpaid)
        let account = try #require(try f.store.journal()).accountID
        let transport = RecoveryTransport(cloud: f.cloud)
        let model = SyncInvoiceRecoveryModel(container: f.local.container,
            transport: transport, currentAccount: { account })
        try await model.load(accountID: account)
        await transport.changeRevision(to: 2)
        let before = try f.store.journal()
        await #expect(throws: SyncInvoiceRecoveryError.changedSinceReview) {
            try await model.confirm(accountID: account, settings: .useCloud)
        }
        #expect(try f.store.journal() == before)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.local.container)) == f.original)
    }

    @Test
    func signedOutReviewCannotReadOrModifyCloudState() async throws {
        let f = try fixture(status: .paid)
        let account = try #require(try f.store.journal()).accountID
        let model = SyncInvoiceRecoveryModel(container: f.local.container,
            transport: RecoveryTransport(cloud: f.cloud), currentAccount: { nil })
        await #expect(throws: SyncJournalError.accountMismatch) { try await model.load(accountID: account) }
        #expect(try f.store.journal()?.invoiceHistoryArchives.isEmpty == true)
    }

    @Test(arguments: [InvoiceStatus.unpaid, .paid])
    func independentNumberCollisionArchivesOriginalAndKeepsCloudInvoice(status: InvoiceStatus) throws {
        let f = try fixture(status: status)
        let review = try SyncInvoiceRecoveryReview.make(current: f.original,
            journal: try #require(try f.store.journal()), cloud: f.cloud, capturedAt: Date(timeIntervalSinceReferenceDate: 800))
        try f.store.applyRecovery(review, settings: .useCloud)
        let journal = try #require(try f.store.journal())
        let archive = try #require(journal.invoiceHistoryArchives.first)
        #expect(archive.invoiceIDs == [f.localInvoiceID])
        #expect(archive.records == f.original)
        #expect(journal.pending == nil && journal.cursor == 1)
        let context = ModelContext(f.local.container)
        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.syncID == f.cloudInvoiceID)
        #expect(try context.fetch(FetchDescriptor<WorkItem>())
            .first(where: { $0.syncID == f.localWorkID })?.billingHoldID == f.localInvoiceID)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 2)
        let content = try InvoiceHistoryArchiveReader(container: f.local.container)
            .content(archiveID: archive.id, invoiceID: f.localInvoiceID)
        #expect(content.number == "0001" && content.totalMinorUnits == 12_500 && content.status == status)
        #expect(try f.store.stage()?.mutations.contains { $0.id == f.localInvoiceID } == false)
    }

    @Test
    func ambiguousPendingUploadCannotBeArchivedOrRetired() throws {
        let f = try fixture(status: .paid, confirmed: false)
        let before = try #require(try f.store.journal())
        #expect(throws: SyncJournalError.pendingUpload) {
            try SyncInvoiceRecoveryReview.make(current: f.original, journal: before,
                cloud: f.cloud, capturedAt: Date())
        }
        #expect(try f.store.journal() == before)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.local.container)) == f.original)
    }

    @Test
    func changedGraphOrOpenDraftRejectsTheWholeRecovery() throws {
        let f = try fixture(status: .unpaid)
        let review = try SyncInvoiceRecoveryReview.make(current: f.original,
            journal: try #require(try f.store.journal()), cloud: f.cloud, capturedAt: Date())
        let before = try f.store.journal()
        let client = try #require(f.local.context.fetch(FetchDescriptor<Client>()).first)
        client.notes = "Unsaved draft"
        #expect(throws: SyncGraphError.unsavedChanges) { try f.store.applyRecovery(review, settings: .keepLocal) }
        #expect(try f.store.journal() == before)
        f.local.context.rollback()
        client.notes = "Committed after review"
        try f.local.context.save()
        #expect(throws: SyncInvoiceRecoveryError.changedSinceReview) {
            try f.store.applyRecovery(review, settings: .keepLocal)
        }
        #expect(try f.store.journal() == before)
    }

    @Test
    func anotherCurrencyOrWorkspaceCannotBeMerged() throws {
        let f = try fixture(status: .unpaid, cloudCurrency: "EUR")
        #expect(throws: SyncInvoiceRecoveryError.incompatibleGraph) {
            try SyncInvoiceRecoveryReview.make(current: f.original,
                journal: try #require(try f.store.journal()), cloud: f.cloud, capturedAt: Date())
        }
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.local.container)) == f.original)
    }

    @Test
    func recoveryQueuesPhotoTombstonesEvenWhenTheyWereNeverInTheLocalBaseline() async throws {
        let f = try fixture(status: .unpaid)
        let account = try #require(try f.store.journal()).accountID
        let photoID = UUID()
        let model = SyncInvoiceRecoveryModel(container: f.local.container,
            transport: TombstoneRecoveryTransport(cloud: f.cloud, photoID: photoID), currentAccount: { account })
        try await model.load(accountID: account)
        #expect(model.review?.cloud.deletedPhotoIDs == [photoID])
        try await model.confirm(accountID: account, settings: .useCloud)
        #expect(try f.store.journal()?.pendingPhotoDeletionIDs == [photoID])
    }

    private func fixture(status: InvoiceStatus, confirmed: Bool = true,
                         cloudCurrency: String = "GBP") throws -> (
        local: InvoiceActionGraph, store: SyncJournalStore, original: [SyncRecord],
        cloud: SyncRecoveryCloudSnapshot, localInvoiceID: UUID, localWorkID: UUID, cloudInvoiceID: UUID
    ) {
        let local = try InvoiceActionGraph.make(status: status, currencyCode: "GBP")
        let remote = try InvoiceActionGraph.make(currencyCode: cloudCurrency)
        let store = SyncJournalStore(container: local.container)
        let account = UUID(), workspace = UUID(), device = UUID()
        try store.bind(accountID: account, workspaceID: workspace, deviceID: device)
        try store.update { $0.invoicingDeviceID = device; $0.invoicingGeneration = 1 }
        let original = try SyncGraphCodec.capture(in: local.context)
        let batch = try #require(try store.stage())
        if confirmed { try store.recordConfirmedRejection(operationID: batch.operationID, reason: .invoiceNumberCollision) }
        let cloudRecords = try SyncGraphCodec.capture(in: remote.context)
        let cloud = SyncRecoveryCloudSnapshot(workspaceID: workspace, revision: 1,
            records: cloudRecords, revisions: Dictionary(uniqueKeysWithValues: cloudRecords.map { ($0.id, Int64(1)) }),
            invoicingDeviceID: UUID(), invoicingGeneration: 2)
        let invoice = try #require(local.context.model(for: local.invoiceID) as? Invoice)
        let work = try #require(local.context.model(for: local.workItemID) as? WorkItem)
        let cloudInvoice = try #require(remote.context.model(for: remote.invoiceID) as? Invoice)
        return (local, store, original, cloud, try #require(invoice.syncID), try #require(work.syncID),
            try #require(cloudInvoice.syncID))
    }
}

private actor RecoveryTransport: SyncTransport {
    let cloud: SyncRecoveryCloudSnapshot
    private var revision: Int64
    init(cloud: SyncRecoveryCloudSnapshot) { self.cloud = cloud; revision = cloud.revision }
    func changeRevision(to value: Int64) { revision = value }
    func bootstrap(deviceID: UUID) -> SyncWorkspaceInfo {
        SyncWorkspaceInfo(workspaceID: cloud.workspaceID, deviceID: deviceID,
            invoicingDeviceID: cloud.invoicingDeviceID, invoicingGeneration: cloud.invoicingGeneration,
            revision: revision, minimumProtocolVersion: 2)
    }
    func push(_ batch: SyncBatch) throws -> SyncPushReceipt { throw SyncTransportError.unsupportedOperation }
    func pull(workspaceID: UUID, cursor: Int64) -> SyncPullPage {
        let transactions: [SyncRemoteTransaction] = cursor == 0 ? [.init(workspaceID: cloud.workspaceID,
            revision: 1, mutations: cloud.records.map { .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0) })] : []
        return SyncPullPage(workspaceID: cloud.workspaceID, cursor: cloud.revision, hasMore: false,
            transactions: transactions, invoicingDeviceID: cloud.invoicingDeviceID,
            invoicingGeneration: cloud.invoicingGeneration)
    }
}

private actor TombstoneRecoveryTransport: SyncTransport {
    let cloud: SyncRecoveryCloudSnapshot
    let photoID: UUID
    init(cloud: SyncRecoveryCloudSnapshot, photoID: UUID) { self.cloud = cloud; self.photoID = photoID }
    func bootstrap(deviceID: UUID) -> SyncWorkspaceInfo {
        .init(workspaceID: cloud.workspaceID, deviceID: deviceID, invoicingDeviceID: cloud.invoicingDeviceID,
              invoicingGeneration: cloud.invoicingGeneration, revision: 2)
    }
    func push(_ batch: SyncBatch) throws -> SyncPushReceipt { throw SyncTransportError.unsupportedOperation }
    func pull(workspaceID: UUID, cursor: Int64) throws -> SyncPullPage {
        let member = try #require(cloud.records.first { $0.kind == .visitHorse })
        let photo = SyncRecord(id: photoID, kind: .photograph, fields: [
            "createdAt": .string("100.0"), "pixelWidth": .integer(10), "pixelHeight": .integer(10),
            "byteCount": .integer(10), "visitHorse": .string(member.id.uuidString.lowercased())])
        let created = SyncRemoteTransaction(workspaceID: workspaceID, revision: 1, mutations: (cloud.records + [photo]).map {
            .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0)
        })
        let deleted = SyncRemoteTransaction(workspaceID: workspaceID, revision: 2, mutations: [
            .init(id: photoID, kind: .photograph, expectedRevision: 1, record: nil)])
        return .init(workspaceID: workspaceID, cursor: 2, hasMore: false,
            transactions: cursor == 0 ? [created, deleted] : [],
            invoicingDeviceID: cloud.invoicingDeviceID, invoicingGeneration: cloud.invoicingGeneration)
    }
}
