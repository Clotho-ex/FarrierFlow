import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice PDF content builder", .serialized)
@MainActor
struct InvoicePDFContentBuilderTests {
    @Test func buildsCompleteContentFromPersistedInvoiceSnapshots() throws {
        let graph = try makeGraph()

        let content = try InvoicePDFContentBuilder.build(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        #expect(content.number == "0001")
        #expect(content.invoiceDate == graph.invoiceDate)
        #expect(content.dueDate == graph.dueDate)
        #expect(content.status == .paid)
        #expect(content.paidAt == graph.paidAt)
        #expect(content.businessName == "Carter Farrier Service")
        #expect(content.businessPhone == "555-0100")
        #expect(content.businessEmail == "office@example.com")
        #expect(content.businessAddress == "1 Main Street")
        #expect(content.clientName == "Alex Carter")
        #expect(content.clientPhone == "555-0101")
        #expect(content.clientEmail == "alex@example.com")
        #expect(content.visits.count == 1)
        #expect(content.visits[0].date == graph.visitDate)
        #expect(content.visits[0].location == "North Field")
        #expect(content.visits[0].address == "25 Stable Lane")
        #expect(content.visits[0].lineItems == [
            .init(horseName: "Milo", serviceName: "Full Set", amountMinorUnits: 12_500),
        ])
        #expect(content.totalMinorUnits == 12_500)
        #expect(content.note == "Thank you.")
    }

    @Test func omitsAbsentOptionalSnapshotValues() throws {
        let graph = try makeGraph(includeOptionalValues: false, status: .unpaid)

        let content = try InvoicePDFContentBuilder.build(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        #expect(content.dueDate == nil)
        #expect(content.paidAt == nil)
        #expect(content.businessPhone == nil)
        #expect(content.businessEmail == nil)
        #expect(content.businessAddress == nil)
        #expect(content.clientPhone == nil)
        #expect(content.clientEmail == nil)
        #expect(content.visits[0].address == nil)
        #expect(content.note == nil)
    }

    @Test func mutableSourceEditsDoNotChangeContentOrOrdering() throws {
        let graph = try makeGraph()
        let original = try InvoicePDFContentBuilder.build(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        graph.profile.name = "Changed Business"
        graph.client.name = "Changed Client"
        graph.horse.name = "Changed Horse"
        graph.service.name = "Changed Service"
        graph.workItem.serviceNameSnapshot = "Changed Work"
        graph.workItem.amountMinorUnits = 1
        graph.visit.startedAt = Date(timeIntervalSinceReferenceDate: 400)
        graph.visit.serviceLocationNameSnapshot = "Changed Location"
        graph.visit.serviceLocationAddressSnapshot = "Changed Address"
        try DomainGraphValidator.save(graph.context)

        let afterSourceEdits = try InvoicePDFContentBuilder.build(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        #expect(afterSourceEdits == original)
    }

    private func makeGraph(
        includeOptionalValues: Bool = true,
        status: InvoiceStatus = .paid
    ) throws -> Graph {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let invoiceDate = Date(timeIntervalSinceReferenceDate: 1_000)
        let dueDate = includeOptionalValues
            ? Date(timeIntervalSinceReferenceDate: 2_000)
            : nil
        let paidAt = status == .paid
            ? Date(timeIntervalSinceReferenceDate: 3_000)
            : nil
        let visitDate = Date(timeIntervalSinceReferenceDate: 500)
        let client = Client(
            name: "Alex Carter",
            phone: includeOptionalValues ? "555-0101" : nil,
            email: includeOptionalValues ? "alex@example.com" : nil
        )
        let barn = Barn(
            name: "North Field",
            address: includeOptionalValues ? "25 Stable Lane" : nil
        )
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let profile = ModelFixtures.makeBusinessProfile(
            name: "Carter Farrier Service",
            phone: includeOptionalValues ? "555-0100" : nil,
            email: includeOptionalValues ? "office@example.com" : nil,
            address: includeOptionalValues ? "1 Main Street" : nil,
            nextInvoiceNumber: 2,
            in: context
        )
        let service = ModelFixtures.makeService(
            name: "Full Set",
            defaultAmountMinorUnits: 12_500,
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: visitDate,
            completedAt: Date(timeIntervalSinceReferenceDate: 600),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [horse],
                in: context
            ),
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: context
        )
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: client,
            businessProfile: profile,
            invoiceDate: invoiceDate,
            dueDate: dueDate,
            note: includeOptionalValues ? "Thank you." : nil,
            status: status,
            paidAt: paidAt,
            in: context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem,
            in: context
        )
        try DomainGraphValidator.save(context)
        return Graph(
            container: container,
            context: context,
            invoice: invoice,
            profile: profile,
            client: client,
            horse: horse,
            service: service,
            workItem: workItem,
            visit: visit,
            invoiceDate: invoiceDate,
            dueDate: dueDate,
            paidAt: paidAt,
            visitDate: visitDate
        )
    }
}

private struct Graph {
    let container: ModelContainer
    let context: ModelContext
    let invoice: Invoice
    let profile: BusinessProfile
    let client: Client
    let horse: Horse
    let service: Service
    let workItem: WorkItem
    let visit: Visit
    let invoiceDate: Date
    let dueDate: Date?
    let paidAt: Date?
    let visitDate: Date
}
