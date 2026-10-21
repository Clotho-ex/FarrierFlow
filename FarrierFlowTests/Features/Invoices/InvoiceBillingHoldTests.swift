import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Archived invoice billing holds", .serialized)
@MainActor
struct InvoiceBillingHoldTests {
    @Test
    func explicitInvoiceDeletionReleasesItsHold() throws {
        let graph = try InvoiceActionGraph.make(currencyCode: "GBP")
        let work = try #require(graph.context.model(for: graph.workItemID) as? WorkItem)
        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        try work.applyBillingHold(try #require(invoice.syncID))
        try DomainGraphValidator.save(graph.context)
        try InvoiceDeletionUseCase.delete(invoiceID: graph.invoiceID, in: graph.context)
        #expect(work.billingHoldID == nil)
        #expect(try InvoiceEligibilityRules.choices(for: try #require(work.visitHorse?.horse?.client?.persistentModelID),
            in: graph.context).count == 1)
        #expect(try ModelContext(graph.container).fetchCount(FetchDescriptor<Invoice>()) == 0)
    }

    @Test
    func holdCannotChangeOrClear() throws {
        let f = try fixture()
        let invoiceID = UUID()
        try f.work.applyBillingHold(invoiceID)
        try f.work.applyBillingHold(invoiceID)
        #expect(throws: (any Error).self) { try f.work.applyBillingHold(UUID()) }
        try DomainGraphValidator.save(f.container.mainContext)
        let reopened = try #require(ModelContext(f.container).fetch(FetchDescriptor<WorkItem>()).first)
        #expect(reopened.billingHoldID == invoiceID)
    }

    @Test
    func heldWorkIsNotSelectableOrBillableAndDoesNotConsumeNumber() throws {
        let f = try fixture()
        try f.work.applyBillingHold(UUID())
        try DomainGraphValidator.save(f.container.mainContext)
        #expect(try InvoiceEligibilityRules.choices(for: f.client.persistentModelID,
            in: f.container.mainContext).isEmpty)
        let draft = InvoiceCreationDraft(clientID: f.client.persistentModelID,
            selectedVisitIDs: [f.visit.persistentModelID], invoiceDate: Date(),
            dueDate: nil, note: "")
        #expect(throws: InvoiceGenerationError.visitNoLongerEligible) {
            try InvoiceGenerationUseCase.generate(draft, in: f.container.mainContext)
        }
        let committed = ModelContext(f.container)
        #expect(try committed.fetchCount(FetchDescriptor<Invoice>()) == 0)
        #expect(try committed.fetch(FetchDescriptor<BusinessProfile>()).first?.nextInvoiceNumber == 17)
    }

    @Test
    func legacyWorkDecodesAsUnheldButRemoteCannotClearACommittedHold() throws {
        let f = try fixture()
        let original = try SyncGraphCodec.capture(in: f.container.mainContext)
        let legacy = original.map { record in
            var fields = record.fields
            if record.kind == .workItem { fields.removeValue(forKey: "billingHoldID") }
            return SyncRecord(id: record.id, kind: record.kind, fields: fields)
        }
        let destination = try ModelContainerFactory.inMemoryTest()
        try SyncGraphCodec.apply(legacy, in: destination.mainContext)
        let work = try #require(destination.mainContext.fetch(FetchDescriptor<WorkItem>()).first)
        #expect(work.billingHoldID == nil)
        try work.applyBillingHold(UUID())
        try DomainGraphValidator.save(destination.mainContext)
        let before = try SyncGraphCodec.capture(in: destination.mainContext)
        #expect(throws: (any Error).self) { try SyncGraphCodec.apply(legacy, in: destination.mainContext) }
        #expect(try SyncGraphCodec.capture(in: ModelContext(destination)) == before)
    }

    private func fixture() throws -> (container: ModelContainer, client: Client, visit: Visit, work: WorkItem) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Pat"), barn = Barn(name: "Stable")
        context.insert(client); context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse); barn.horses.append(horse)
        _ = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 17, currencyCode: "GBP", in: context)
        let service = ModelFixtures.makeService(currencyCode: "GBP", in: context)
        let appointment = ModelFixtures.makeAppointment(startDate: Date(timeIntervalSinceReferenceDate: 100),
            barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200), appointment: appointment, in: context)
        let member = try #require(visit.visitHorses.first)
        member.outcomeRawValue = VisitOutcome.serviced.rawValue
        let work = ModelFixtures.makeWorkItem(service: service, visitHorse: member, in: context)
        try DomainGraphValidator.save(context)
        return (container, client, visit, work)
    }
}
