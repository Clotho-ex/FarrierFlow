import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice list model", .serialized)
@MainActor
struct InvoiceListModelTests {
    @Test
    func summariesUseSnapshotsAndDescendingInvoiceNumbers() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Current Client Name")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 3, in: context)
        let service = ModelFixtures.makeService(in: context)
        let firstVisit = try completedVisit(
            horse: horse,
            barn: barn,
            service: service,
            startedAt: 100,
            in: context
        )
        let secondVisit = try completedVisit(
            horse: horse,
            barn: barn,
            service: service,
            startedAt: 200,
            in: context
        )
        let first = ModelFixtures.makeInvoice(number: 1, client: client, businessProfile: profile, in: context)
        let second = ModelFixtures.makeInvoice(number: 2, client: client, businessProfile: profile, in: context)
        let firstGroup = ModelFixtures.makeInvoiceVisit(invoice: first, sourceVisit: firstVisit, in: context)
        let secondGroup = ModelFixtures.makeInvoiceVisit(invoice: second, sourceVisit: secondVisit, in: context)
        _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: firstGroup, sourceWorkItem: try workItem(in: firstVisit), in: context)
        _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: secondGroup, sourceWorkItem: try workItem(in: secondVisit), in: context)
        client.name = "Renamed Client"
        try DomainGraphValidator.save(context)

        let model = InvoiceListModel()
        model.load(in: context, locale: Locale(identifier: "en_US"))

        #expect(model.loadState == .loaded)
        #expect(model.summaries.map(\.number) == ["0002", "0001"])
        #expect(model.summaries.map(\.clientName) == ["Current Client Name", "Current Client Name"])
        #expect(model.summaries.allSatisfy { $0.status == .unpaid })
        #expect(model.summaries.allSatisfy { $0.total == .available(12_500) })
    }

    private func completedVisit(horse: Horse, barn: Barn, service: Service, startedAt: TimeInterval, in context: ModelContext) throws -> Visit {
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: Date(timeIntervalSinceReferenceDate: startedAt), completedAt: Date(timeIntervalSinceReferenceDate: startedAt + 10), appointment: appointment, in: context)
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        _ = ModelFixtures.makeWorkItem(service: service, visitHorse: visitHorse, in: context)
        return visit
    }

    private func workItem(in visit: Visit) throws -> WorkItem {
        try #require(visit.visitHorses.first?.workItems.first)
    }
}
