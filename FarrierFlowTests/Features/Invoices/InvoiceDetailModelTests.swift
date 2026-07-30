import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice detail model", .serialized)
@MainActor
struct InvoiceDetailModelTests {
    @Test
    func detailProjectsOnlyPersistedSnapshotsInOrderedVisitGroups() throws {
        let graph = try makeGraph()
        let model = InvoiceDetailModel(invoiceID: graph.invoiceID)

        model.load(in: graph.context, locale: Locale(identifier: "en_US"))

        let detail = try #require(model.detail)
        #expect(detail.number == "0001")
        #expect(detail.businessName == "Carter Farrier Service")
        #expect(detail.clientName == "Alex Carter")
        #expect(detail.status == .unpaid)
        #expect(detail.total == .available(12_500))
        #expect(detail.visits.count == 1)
        #expect(detail.visits[0].lineItems.map(\.horseName) == ["Milo"])
        #expect(detail.visits[0].lineItems.map(\.serviceName) == ["Trim"])
    }

    private func makeGraph() throws -> InvoiceDetailGraph {
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
        let profile = ModelFixtures.makeBusinessProfile(name: "Carter Farrier Service", nextInvoiceNumber: 2, in: context)
        let service = ModelFixtures.makeService(name: "Trim", in: context)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: Date(timeIntervalSinceReferenceDate: 100), completedAt: Date(timeIntervalSinceReferenceDate: 110), appointment: appointment, in: context)
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let workItem = ModelFixtures.makeWorkItem(service: service, visitHorse: visitHorse, in: context)
        let invoice = ModelFixtures.makeInvoice(number: 1, client: client, businessProfile: profile, in: context)
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(invoice: invoice, sourceVisit: visit, in: context)
        _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: invoiceVisit, sourceWorkItem: workItem, in: context)
        try DomainGraphValidator.save(context)
        return InvoiceDetailGraph(container: container, context: context, invoiceID: invoice.persistentModelID)
    }
}

private struct InvoiceDetailGraph {
    let container: ModelContainer
    let context: ModelContext
    let invoiceID: PersistentIdentifier
}
