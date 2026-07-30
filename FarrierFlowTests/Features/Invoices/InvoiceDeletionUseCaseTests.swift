import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice deletion use case", .serialized)
@MainActor
struct InvoiceDeletionUseCaseTests {
    @Test
    func deletingAnUnpaidInvoiceReleasesOnlyItsWorkItemAndRestoresCorrectionWhenLastReferenceIsRemoved() throws {
        let graph = try InvoiceActionGraph.make()
        let visit = try #require(graph.context.model(for: graph.visitID) as? Visit)
        #expect(InvoiceDomainRules.isCorrectionLocked(visit))

        try InvoiceDeletionUseCase.deleteUnpaid(invoiceID: graph.invoiceID, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<Invoice>()) == 0)
        #expect((try #require(graph.context.model(for: graph.workItemID) as? WorkItem)).invoiceLineItem == nil)
        #expect(!InvoiceDomainRules.isCorrectionLocked(visit))
        #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 1)
    }

    @Test
    func paidInvoicesCannotBeDeleted() throws {
        let graph = try InvoiceActionGraph.make(status: .paid)

        #expect(throws: InvoiceDeletionError.invoicePaid) {
            try InvoiceDeletionUseCase.deleteUnpaid(invoiceID: graph.invoiceID, in: graph.context)
        }
        #expect(graph.context.model(for: graph.invoiceID) as? Invoice != nil)
    }
}

@MainActor
struct InvoiceActionGraph {
    let container: ModelContainer
    let context: ModelContext
    let invoiceID: PersistentIdentifier
    let visitID: PersistentIdentifier
    let workItemID: PersistentIdentifier

    static func make(status: InvoiceStatus = .unpaid) throws -> Self {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 2, in: context)
        let service = ModelFixtures.makeService(name: "Trim", in: context)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: Date(timeIntervalSinceReferenceDate: 100), completedAt: Date(timeIntervalSinceReferenceDate: 110), appointment: appointment, in: context)
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let workItem = ModelFixtures.makeWorkItem(service: service, visitHorse: visitHorse, in: context)
        let invoice = ModelFixtures.makeInvoice(number: 1, client: client, businessProfile: profile, status: status, paidAt: status == .paid ? Date(timeIntervalSinceReferenceDate: 500) : nil, in: context)
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(invoice: invoice, sourceVisit: visit, in: context)
        _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: invoiceVisit, sourceWorkItem: workItem, in: context)
        try DomainGraphValidator.save(context)
        return Self(container: container, context: context, invoiceID: invoice.persistentModelID, visitID: visit.persistentModelID, workItemID: workItem.persistentModelID)
    }
}
