import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@MainActor
enum ExportTestFixtures {
    static let photographID = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!

    static func makeCompleteGraph() throws -> CompleteGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let mutationCoordinator = PersistenceMutationCoordinator()
        let exportContext = ExportContext(
            createdAt: date(9_000),
            localeIdentifier: "en_US",
            calendarIdentifier: .gregorian,
            timeZoneIdentifier: "America/New_York"
        )

        let profile = ModelFixtures.makeBusinessProfile(
            name: "Carter Farrier Service",
            phone: "555-0100",
            email: "office@example.com",
            address: "1 Main Street",
            defaultInvoiceNote: "Thank you.",
            defaultAppointmentDurationMinutes: 75,
            defaultInvoiceDueDays: 21,
            nextInvoiceNumber: 3,
            in: context
        )
        let alex = Client(
            name: "Alex Carter",
            phone: "555-0101",
            email: "alex@example.com",
            notes: "Use the north gate."
        )
        let blair = Client(name: "Blair Stone")
        let northField = Barn(
            name: "North Field",
            address: "25 Stable Lane",
            contactNotes: "Gate code 2468"
        )
        let southField = Barn(name: "South Field")
        for model in [alex, blair] { context.insert(model) }
        for model in [northField, southField] { context.insert(model) }

        let trim = ModelFixtures.makeService(
            name: "Trim",
            defaultAmountMinorUnits: 6_500,
            in: context
        )
        let fullSet = ModelFixtures.makeService(
            name: "Full Set",
            defaultAmountMinorUnits: 18_500,
            in: context
        )
        let archivedPads = ModelFixtures.makeService(
            name: "Legacy Pads",
            defaultAmountMinorUnits: 4_000,
            isArchived: true,
            in: context
        )

        let milo = Horse(
            name: "Milo",
            safetyNotes: "Left hind is sensitive.",
            appointmentIntervalWeeks: 6,
            client: alex,
            currentBarn: northField,
            defaultService: trim
        )
        let scout = Horse(
            name: "Scout",
            appointmentIntervalWeeks: 8,
            client: blair,
            currentBarn: northField
        )
        let river = Horse(
            name: "River",
            appointmentIntervalWeeks: 5,
            client: alex,
            currentBarn: northField
        )
        let ember = Horse(
            name: "Ember",
            appointmentIntervalWeeks: 7,
            client: blair,
            currentBarn: southField
        )
        for horse in [milo, scout, river, ember] { context.insert(horse) }
        alex.horses.append(contentsOf: [milo, river])
        blair.horses.append(contentsOf: [scout, ember])
        northField.horses.append(contentsOf: [milo, scout, river])
        southField.horses.append(ember)
        trim.horsesUsingAsDefault.append(milo)

        let completedAppointment = ModelFixtures.makeAppointment(
            startDate: date(1_000),
            barn: northField,
            horses: [milo, scout, river],
            in: context
        )
        completedAppointment.notes = "Mixed-client morning visit"
        completedAppointment.expectedDurationMinutes = 120
        let completedVisit = ModelFixtures.makeVisit(
            startedAt: date(1_100),
            completedAt: date(1_500),
            appointment: completedAppointment,
            in: context
        )
        let miloVisitHorse = try requiredVisitHorse(for: milo, in: completedVisit)
        let scoutVisitHorse = try requiredVisitHorse(for: scout, in: completedVisit)
        let riverVisitHorse = try requiredVisitHorse(for: river, in: completedVisit)
        miloVisitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        miloVisitHorse.workNotes = "Balanced front feet."
        scoutVisitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        riverVisitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue

        let miloWorkItem = ModelFixtures.makeWorkItem(
            service: trim,
            visitHorse: miloVisitHorse,
            in: context
        )
        let scoutWorkItem = ModelFixtures.makeWorkItem(
            service: fullSet,
            visitHorse: scoutVisitHorse,
            in: context
        )
        let photograph = Photograph(
            id: photographID,
            createdAt: date(1_200),
            pixelWidth: 2_000,
            pixelHeight: 1_500,
            byteCount: 42_000,
            visitHorse: miloVisitHorse
        )
        context.insert(photograph)
        miloVisitHorse.photographs.append(photograph)

        let inProgressAppointment = ModelFixtures.makeAppointment(
            startDate: date(2_000),
            barn: southField,
            horses: [ember],
            in: context
        )
        let inProgressVisit = ModelFixtures.makeVisit(
            startedAt: date(2_100),
            appointment: inProgressAppointment,
            in: context
        )
        let emberVisitHorse = try requiredVisitHorse(for: ember, in: inProgressVisit)
        emberVisitHorse.outcomeRawValue = VisitOutcome.pending.rawValue

        let unpaidInvoice = ModelFixtures.makeInvoice(
            number: 1,
            client: alex,
            businessProfile: profile,
            invoiceDate: date(3_000),
            dueDate: date(4_000),
            note: "Alex invoice snapshot note.",
            status: .unpaid,
            in: context
        )
        let alexInvoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: unpaidInvoice,
            sourceVisit: completedVisit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: alexInvoiceVisit,
            sourceWorkItem: miloWorkItem,
            in: context
        )

        let paidInvoice = ModelFixtures.makeInvoice(
            number: 2,
            client: blair,
            businessProfile: profile,
            invoiceDate: date(3_100),
            dueDate: nil,
            note: nil,
            status: .paid,
            paidAt: date(3_500),
            in: context
        )
        let blairInvoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: paidInvoice,
            sourceVisit: completedVisit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: blairInvoiceVisit,
            sourceWorkItem: scoutWorkItem,
            in: context
        )

        profile.name = "Current Carter Farrier"
        alex.name = "Current Alex Carter"
        milo.name = "Current Milo"
        trim.name = "Current Trim"
        completedVisit.serviceLocationNameSnapshot = "Current North Field"
        try DomainGraphValidator.save(context)

        return CompleteGraph(
            container: container,
            context: context,
            mutationCoordinator: mutationCoordinator,
            exportContext: exportContext,
            profile: profile,
            clients: [alex, blair],
            barns: [northField, southField],
            horses: [milo, scout, river, ember],
            appointments: [completedAppointment, inProgressAppointment],
            visits: [completedVisit, inProgressVisit],
            visitHorses: [miloVisitHorse, scoutVisitHorse, riverVisitHorse, emberVisitHorse],
            photograph: photograph,
            services: [trim, fullSet, archivedPads],
            workItems: [miloWorkItem, scoutWorkItem],
            invoices: [unpaidInvoice, paidInvoice]
        )
    }

    static func appendInvoiceLineItems(count: Int, to graph: CompleteGraph) throws {
        let invoiceVisit = try #require(graph.invoices[0].invoiceVisits.first)
        let visitHorse = graph.visitHorses[0]

        for offset in 0..<count {
            let index = offset + 1
            let service = ModelFixtures.makeService(
                name: "Nested Service \(index)",
                defaultAmountMinorUnits: Int64(1_000 + index),
                in: graph.context
            )
            let workItem = ModelFixtures.makeWorkItem(
                service: service,
                visitHorse: visitHorse,
                in: graph.context
            )
            _ = try ModelFixtures.makeInvoiceLineItem(
                invoiceVisit: invoiceVisit,
                sourceWorkItem: workItem,
                in: graph.context
            )
        }
        try DomainGraphValidator.save(graph.context)
    }

    private static func requiredVisitHorse(for horse: Horse, in visit: Visit) throws -> VisitHorse {
        try #require(visit.visitHorses.first(where: { $0.horse === horse }))
    }

    private static func date(_ interval: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: interval)
    }
}

@MainActor
struct CompleteGraph {
    let container: ModelContainer
    let context: ModelContext
    let mutationCoordinator: PersistenceMutationCoordinator
    let exportContext: ExportContext
    let profile: BusinessProfile
    let clients: [Client]
    let barns: [Barn]
    let horses: [Horse]
    let appointments: [Appointment]
    let visits: [Visit]
    let visitHorses: [VisitHorse]
    let photograph: Photograph
    let services: [Service]
    let workItems: [WorkItem]
    let invoices: [Invoice]
}
