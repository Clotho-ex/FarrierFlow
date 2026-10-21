import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("User-controlled record deletion")
@MainActor
struct UserControlledDeletionTests {
    @Test
    func deletingHorseKeepsPaidInvoiceSnapshotsAndOtherHorses() throws {
        let graph = try graphWithPaidWork()
        try RecordDeletionRules.delete(graph.horse, in: graph.context)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<VisitHorse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 1)
        #expect(graph.invoice.statusRawValue == "paid")
        #expect(graph.invoice.payments.count == 1)
        #expect(graph.invoice.invoiceVisits.first?.lineItems.first?.horseNameSnapshot == "Delete Horse")
        #expect(graph.invoice.invoiceVisits.first?.lineItems.first?.sourceWorkItem == nil)
        try DomainGraphValidator.validateAll(in: graph.context)
    }

    @Test(arguments: ["client", "horse", "service", "barn", "appointment", "visit", "invoice", "work"])
    func deletionRoundTripsToExistingAndNewDevices(_ kind: String) throws {
        let graph = try graphWithPaidWork()
        let before = try SyncGraphCodec.capture(in: graph.context)
        let receiver = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(before, in: receiver.mainContext)
        let target = try target(kind, graph: graph)
        let impact = try RecordDeletionPlan(target: target, in: graph.context).impact
        try RecordDeletionPlan.execute(target, confirming: impact, in: graph.context)
        let after = try SyncGraphCodec.capture(in: graph.context)
        try SyncGraphCodec.apply(after, in: receiver.mainContext)
        #expect(try SyncGraphCodec.capture(in: receiver.mainContext) == after)
        let fresh = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(after, in: fresh.mainContext)
        #expect(try SyncGraphCodec.capture(in: fresh.mainContext) == after)
        if kind == "invoice" {
            #expect(try graph.context.fetchCount(FetchDescriptor<Invoice>()) == 0)
            #expect(try graph.context.fetchCount(FetchDescriptor<Payment>()) == 0)
            #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 2)
        } else {
            let invoice = try #require(after.first { $0.kind == .invoice })
            let old = try #require(before.first { $0.id == invoice.id })
            #expect(invoice.fields.filter { $0.key != "client" } == old.fields.filter { $0.key != "client" })
            #expect(after.filter { $0.kind == .payment } == before.filter { $0.kind == .payment })
            let pdf = try InvoicePDFContentBuilder.build(invoiceID: graph.invoice.persistentModelID, in: graph.context)
            #expect(pdf.totalMinorUnits == 12_500)
            #expect(pdf.payment?.amountMinorUnits == 12_500)
            #expect(after.filter { $0.kind == .invoiceLineItem }.map { $0.fields["amountMinorUnits"] } == before.filter { $0.kind == .invoiceLineItem }.map { $0.fields["amountMinorUnits"] })
        }
        if kind == "client" || kind == "horse" {
            #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
            #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 1)
            #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 1)
        }
        if ["barn", "appointment", "visit"].contains(kind) {
            #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 0)
            #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 0)
        }
        if kind == "service" {
            #expect(try graph.context.fetch(FetchDescriptor<VisitHorse>()).allSatisfy { $0.outcomeRawValue == "notServiced" })
        }
    }

    @Test(arguments: ["client", "horse", "service", "barn", "appointment", "visit", "invoice", "work"])
    func failedDeletionRestoresEntireGraph(_ kind: String) throws {
        let graph = try graphWithPaidWork()
        let before = try SyncGraphCodec.capture(in: graph.context)
        let target = try target(kind, graph: graph)
        #expect(throws: ForcedFailure.expected) {
            try RecordDeletionPlan.execute(target, in: graph.context, saving: { _ in throw ForcedFailure.expected })
        }
        #expect(try SyncGraphCodec.capture(in: ModelContext(graph.container)) == before)
    }

    @Test
    func changedDependenciesRequireNewConfirmationWithoutDeletingAnything() throws {
        let graph = try graphWithPaidWork()
        let target = RecordDeletionTarget.horse(graph.horse.persistentModelID)
        let expected = try RecordDeletionPlan(target: target, in: graph.context).impact
        let barn = try #require(graph.horse.currentBarn)
        _ = ModelFixtures.makeAppointment(barn: barn, horses: [graph.horse], in: graph.context)
        try DomainGraphValidator.save(graph.context)
        let before = try SyncGraphCodec.capture(in: graph.context)
        #expect(throws: RecordDeletionError.dependenciesChanged) {
            try RecordDeletionPlan.execute(target, confirming: expected, in: graph.context)
        }
        #expect(try SyncGraphCodec.capture(in: graph.context) == before)
    }

    @Test
    func correctingPaidVisitToNotServicedSavesAndKeepsInvoice() throws {
        let graph = try graphWithPaidWork()
        let visit = try #require(graph.context.fetch(FetchDescriptor<Visit>()).first)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visit.persistentModelID, in: graph.context)
        for index in draft.horses.indices {
            draft.horses[index].outcome = .notServiced
            draft.horses[index].workItems = []
            draft.horses[index].workNotes = ""
        }
        #expect(VisitRules.correctionViolation(in: draft) == nil)
        _ = try VisitSaveUseCase.saveCorrection(draft: draft, in: graph.context)
        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
        #expect(graph.invoice.statusRawValue == "paid")
        #expect(graph.invoice.invoiceVisits.first?.lineItems.first?.amountMinorUnits == 12_500)
        #expect(graph.invoice.invoiceVisits.first?.lineItems.first?.sourceWorkItem == nil)
    }

    @Test
    func detachedFinancialSnapshotsSurvivePersistentReopen() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(prefix: "FarrierFlow-Detached-Invoices-")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "records.store")
        let graph = try graphWithPaidWork()
        var expected: [SyncRecord] = []
        do {
            let container = try ModelContainerFactory.persistentStoreTest(at: url)
            try SyncGraphCodec.apply(SyncGraphCodec.capture(in: graph.context), in: container.mainContext)
            let client = try #require(container.mainContext.fetch(FetchDescriptor<Client>()).first { $0.name == "Delete Client" })
            try RecordDeletionRules.delete(client, in: container.mainContext)
            expected = try SyncGraphCodec.capture(in: container.mainContext)
        }
        let reopened = try ModelContainerFactory.persistentStoreTest(at: url)
        #expect(try SyncGraphCodec.capture(in: reopened.mainContext) == expected)
    }

    @Test
    func correctingBilledWorkAndSeparatelyDeletingInvoiceSyncsWithoutRepeatBilling() throws {
        let graph = try graphWithPaidWork()
        let before = try SyncGraphCodec.capture(in: graph.context)
        let receiver = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(before, in: receiver.mainContext)
        let visit = try #require(graph.context.fetch(FetchDescriptor<Visit>()).first)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visit.persistentModelID, in: graph.context)
        let index = try #require(draft.horses.firstIndex { $0.horseName == "Delete Horse" })
        draft.horses[index].workItems[0].amountMinorUnits = 20_000
        _ = try VisitSaveUseCase.saveCorrection(draft: draft, in: graph.context)
        let corrected = try SyncGraphCodec.capture(in: graph.context)
        try SyncGraphCodec.apply(corrected, in: receiver.mainContext)
        let item = try #require(receiver.mainContext.fetch(FetchDescriptor<WorkItem>()).first { $0.visitHorse?.horse?.name == "Delete Horse" })
        #expect(item.billingHoldID == graph.invoice.syncID)
        #expect(graph.invoice.invoiceVisits.first?.lineItems.first?.amountMinorUnits == 12_500)
        let forged = corrected.map { record in
            guard record.id == item.syncID else { return record }
            var fields = record.fields
            fields["billingHoldID"] = .null
            return SyncRecord(id: record.id, kind: record.kind, fields: fields)
        }
        #expect(throws: BillingHoldError.immutableHold) {
            try SyncGraphCodec.apply(forged, in: receiver.mainContext)
        }
        try InvoiceDeletionUseCase.delete(invoiceID: graph.invoice.persistentModelID, in: graph.context)
        let deleted = try SyncGraphCodec.capture(in: graph.context)
        try SyncGraphCodec.apply(deleted, in: receiver.mainContext)
        #expect(item.billingHoldID == nil)
        #expect(item.amountMinorUnits == 20_000)
        #expect(try SyncGraphCodec.capture(in: receiver.mainContext) == deleted)
    }

    @Test
    func detachedInvoiceCanBeArchivedAndValidated() throws {
        let graph = try graphWithPaidWork()
        let invoiceID = try #require(graph.invoice.syncID)
        try RecordDeletionRules.delete(try #require(graph.horse.client), in: graph.context)
        let pdf = try InvoicePDFContentBuilder.build(invoiceID: graph.invoice.persistentModelID, in: graph.context)
        #expect(pdf.clientName == "Delete Client")
        #expect(pdf.visits.first?.lineItems.first?.horseName == "Delete Horse")
        #expect(pdf.totalMinorUnits == 12_500)
        #expect(pdf.payment?.amountMinorUnits == 12_500)
        let archive = try InvoiceHistoryArchive(accountID: UUID(), workspaceID: UUID(), capturedAt: .now,
            reason: .numberCollision, sourceOperationID: nil,
            records: SyncGraphCodec.capture(in: graph.context), invoiceIDs: [invoiceID])
        try archive.validate()
        #expect(archive.sourceWorkItemIDs[invoiceID] == [])
    }

    @Test(arguments: [false, true])
    func photographCascadeCommitsOrRestoresFilesOnSaveFailure(_ failSave: Bool) async throws {
        let graph = try graphWithPaidWork()
        let directory = try TemporaryStoreFixtures.makeDirectory(prefix: "FarrierFlow-Cascade-Photos-\(UUID())-")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PhotographFileStore(rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory))
        let library = PhotographLibrary(container: graph.container, fileStore: store, protectedDataAvailable: { true })
        let member = try #require(graph.horse.visitHorses.first)
        let photoID = try await library.add(sourceData: PhotographTestFixtures.jpeg(), to: member.persistentModelID)
        let before = try SyncGraphCodec.capture(in: ModelContext(graph.container))
        let deletingLibrary = PhotographLibrary(container: graph.container, fileStore: store, protectedDataAvailable: { true },
            saving: { context in
                if failSave { throw ForcedFailure.expected }
                try DomainGraphValidator.save(context)
            })
        let target = RecordDeletionTarget.horse(graph.horse.persistentModelID)
        let impact = try RecordDeletionPlan(target: target, in: ModelContext(graph.container)).impact
        #expect(impact.photoIDs == [photoID])
        if failSave {
            await #expect(throws: ForcedFailure.expected) { try await deletingLibrary.deleteRecords(confirming: impact) }
            #expect(try SyncGraphCodec.capture(in: ModelContext(graph.container)) == before)
            #expect(FileManager.default.fileExists(atPath: store.canonicalURL(for: photoID).path))
        } else {
            try await deletingLibrary.deleteRecords(confirming: impact)
            #expect(try ModelContext(graph.container).fetchCount(FetchDescriptor<Photograph>()) == 0)
            #expect(!FileManager.default.fileExists(atPath: store.canonicalURL(for: photoID).path))
        }
        #expect(try store.inspectAllEntries().quarantineFiles.isEmpty)

    }

    @Test(arguments: ["client", "horse", "service", "barn", "appointment", "visit", "invoice", "work"])
    func cascadeRemainsAtomicWhenSyncBatchLimitIsOne(_ kind: String) throws {
        let graph = try graphWithPaidWork()
        let before = try SyncGraphCodec.capture(in: graph.context)
        try RecordDeletionPlan.execute(target(kind, graph: graph), in: graph.context)
        let after = try SyncGraphCodec.capture(in: graph.context)
        let old = try SyncJournal.index(before), new = try SyncJournal.index(after)
        let mutations = Set(old.keys).union(new.keys).compactMap { id -> SyncMutation? in
            guard old[id] != new[id], let kind = old[id]?.kind ?? new[id]?.kind else { return nil }
            return SyncMutation(id: id, kind: kind, expectedRevision: old[id] == nil ? 0 : 1, record: new[id])
        }
        let selected = try SyncBatchPlanner.select(from: mutations, baseline: before, headerBytes: 0, softLimit: 1)
        var partial = old
        for mutation in selected { partial[mutation.id] = mutation.record }
        _ = try SyncGraphCodec.readOnlyGraph(Array(partial.values))
        #expect(Set(selected.map(\.id)) == Set(mutations.map(\.id)))
    }

    private enum ForcedFailure: Error { case expected }

    private func target(_ kind: String, graph: Graph) throws -> RecordDeletionTarget {
        switch kind {
        case "client": .client(try #require(graph.horse.client).persistentModelID)
        case "horse": .horse(graph.horse.persistentModelID)
        case "service": .service(try #require(graph.context.fetch(FetchDescriptor<Service>()).first).persistentModelID)
        case "barn": .barn(try #require(graph.horse.currentBarn).persistentModelID)
        case "appointment": .appointment(try #require(graph.context.fetch(FetchDescriptor<Appointment>()).first).persistentModelID)
        case "visit": .visit(try #require(graph.context.fetch(FetchDescriptor<Visit>()).first).persistentModelID)
        case "invoice": .invoice(graph.invoice.persistentModelID)
        default: .workItem(try #require(graph.context.fetch(FetchDescriptor<WorkItem>()).first { $0.visitHorse?.horse === graph.horse }).persistentModelID)
        }
    }

    private typealias Graph = (container: ModelContainer, context: ModelContext, horse: Horse, invoice: Invoice)

    private func graphWithPaidWork() throws -> Graph {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Delete Client")
        let other = Client(name: "Keep Client")
        let barn = Barn(name: "Shared Barn")
        context.insert(client); context.insert(other); context.insert(barn)
        let horse = Horse(name: "Delete Horse", client: client, currentBarn: barn)
        let otherHorse = Horse(name: "Keep Horse", client: other, currentBarn: barn)
        context.insert(horse); context.insert(otherHorse)
        client.horses = [horse]; other.horses = [otherHorse]; barn.horses = [horse, otherHorse]
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse, otherHorse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: Date(timeIntervalSinceReferenceDate: 100), completedAt: Date(timeIntervalSinceReferenceDate: 200), appointment: appointment, in: context)
        let service = ModelFixtures.makeService(name: "Trim", in: context)
        for member in visit.visitHorses {
            member.outcomeRawValue = VisitOutcome.serviced.rawValue
            _ = ModelFixtures.makeWorkItem(service: service, visitHorse: member, in: context)
        }
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 2, in: context)
        let invoice = ModelFixtures.makeInvoice(number: 1, client: client, businessProfile: profile, in: context)
        let group = ModelFixtures.makeInvoiceVisit(invoice: invoice, sourceVisit: visit, in: context)
        let source = try #require(visit.visitHorses.first(where: { $0.horse === horse })?.workItems.first)
        _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: group, sourceWorkItem: source, in: context)
        try DomainGraphValidator.save(context)
        try InvoicePaymentUseCase.recordPayment(invoiceID: invoice.persistentModelID, method: .cash, receivedAt: Date(timeIntervalSinceReferenceDate: 500), in: context)
        return (container, context, horse, invoice)
    }
}
