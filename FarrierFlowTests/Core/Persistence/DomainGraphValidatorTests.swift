import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Domain graph validation", .serialized)
@MainActor
struct DomainGraphValidatorTests {
    @Test
    func validConnectedGraphSatisfiesEveryRequiredRelationship() throws {
        let graph = try makeGraph()

        try DomainGraphValidator.validateAll(in: graph.context)
    }

    @Test
    func saveRejectsHorseWithoutClient() throws {
        let graph = try makeGraph()
        graph.horse.client = nil

        #expect(throws: DomainGraphViolation.horseMissingClient) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsHorseWithoutCurrentBarn() throws {
        let graph = try makeGraph()
        graph.horse.currentBarn = nil

        #expect(throws: DomainGraphViolation.horseMissingCurrentBarn) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsAppointmentWithoutBarn() throws {
        let graph = try makeGraph()
        graph.appointment.barn = nil

        #expect(throws: DomainGraphViolation.appointmentMissingBarn) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsJoinWithoutAppointment() throws {
        let graph = try makeGraph()
        graph.appointmentHorse.appointment = nil

        #expect(throws: DomainGraphViolation.appointmentHorseMissingAppointment) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsJoinWithoutHorse() throws {
        let graph = try makeGraph()
        graph.appointmentHorse.horse = nil

        #expect(throws: DomainGraphViolation.appointmentHorseMissingHorse) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsAppointmentWithoutMemberships() throws {
        let graph = try makeGraph()
        graph.context.delete(graph.appointmentHorse)

        #expect(throws: DomainGraphViolation.appointmentHasNoValidHorse) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsHorseOutsideAppointmentBarn() throws {
        let graph = try makeGraph()
        let otherBarn = Barn(name: "South Field")
        graph.context.insert(otherBarn)
        graph.horse.currentBarn = otherBarn

        #expect(throws: DomainGraphViolation.horseOutsideAppointmentBarn) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsDuplicateHorseMembership() throws {
        let graph = try makeGraph()
        let duplicate = AppointmentHorse(
            appointment: graph.appointment,
            horse: graph.horse
        )
        graph.context.insert(duplicate)
        graph.appointment.appointmentHorses.append(duplicate)
        graph.horse.appointmentHorses.append(duplicate)

        #expect(throws: DomainGraphViolation.duplicateHorseMembership) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func validCompletedVisitGraphSatisfiesEveryRequiredRelationship() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )

        try DomainGraphValidator.validateAll(in: graph.context)
    }

    @Test(arguments: [
        ("appointment", DomainGraphViolation.visitMissingAppointment),
        ("barn", DomainGraphViolation.visitMissingBarn),
    ])
    func saveRejectsVisitWithoutRequiredRelationship(
        missingRelationship: String,
        expectedViolation: DomainGraphViolation
    ) throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)

        switch missingRelationship {
        case "appointment":
            visit.appointment = nil
        case "barn":
            visit.barn = nil
        default:
            Issue.record("Unexpected relationship fixture")
        }

        #expect(throws: expectedViolation) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsVisitWithoutHorseMembership() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        for visitHorse in visit.visitHorses {
            graph.context.delete(visitHorse)
        }

        #expect(throws: DomainGraphViolation.visitHasNoHorse) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test(arguments: [
        ("visit", DomainGraphViolation.visitHorseMissingVisit),
        ("horse", DomainGraphViolation.visitHorseMissingHorse),
    ])
    func saveRejectsVisitHorseWithoutRequiredRelationship(
        missingRelationship: String,
        expectedViolation: DomainGraphViolation
    ) throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let visitHorse = try #require(visit.visitHorses.first)

        switch missingRelationship {
        case "visit":
            visitHorse.visit = nil
        case "horse":
            visitHorse.horse = nil
        default:
            Issue.record("Unexpected relationship fixture")
        }

        #expect(throws: expectedViolation) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsDuplicateVisitHorseMembership() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let duplicate = VisitHorse(visit: visit, horse: graph.horse)
        graph.context.insert(duplicate)
        visit.visitHorses.append(duplicate)
        graph.horse.visitHorses.append(duplicate)

        #expect(throws: DomainGraphViolation.duplicateVisitHorseMembership) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsVisitHorseSetThatDiffersFromAppointmentHorseSet() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let secondClient = Client(name: "Jordan")
        let secondHorse = Horse(name: "Scout", client: secondClient, currentBarn: graph.barn)
        graph.context.insert(secondClient)
        graph.context.insert(secondHorse)
        secondClient.horses.append(secondHorse)
        graph.barn.horses.append(secondHorse)
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.horse = secondHorse
        secondHorse.visitHorses.append(visitHorse)

        #expect(throws: DomainGraphViolation.visitMembershipMismatch) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsVisitWithBlankLocationNameSnapshot() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        visit.serviceLocationNameSnapshot = " \n "

        #expect(throws: DomainGraphViolation.visitLocationNameMissing) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsInProgressValidationWhenVisitAlreadyHasCompletionDate() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.inProgressVisitHasCompletionDate) {
            try DomainGraphValidator.validateInProgress(visit)
        }
    }

    @Test
    func saveRejectsCompletedVisitWithPendingHorse() throws {
        let graph = try makeGraph()
        _ = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.completedVisitHasPendingHorse) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsCompletedVisitWithoutServicedHorse() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        for visitHorse in visit.visitHorses {
            visitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue
        }

        #expect(throws: DomainGraphViolation.completedVisitHasNoServicedHorse) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsCompletionBeforeStart() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            completedAt: Date(timeIntervalSinceReferenceDate: 100),
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.completionPredatesStart) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsWorkNotesForUnservicedHorse() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue
        visitHorse.workNotes = "Could not safely handle"

        #expect(throws: DomainGraphViolation.workNotesRequireServicedOutcome) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func saveRejectsAppointmentAndVisitWithMismatchedInverse() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        let otherBarn = Barn(name: "South Field")
        graph.context.insert(otherBarn)
        visit.barn = otherBarn
        otherBarn.visits.append(visit)

        #expect(throws: DomainGraphViolation.appointmentVisitMismatch) {
            try DomainGraphValidator.save(graph.context)
        }
    }

    @Test
    func completedVisitAllowsHorseToMoveAfterItsAppointment() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: graph.context
        )
        let otherBarn = Barn(name: "South Field")
        graph.context.insert(otherBarn)
        graph.horse.currentBarn = otherBarn
        otherBarn.horses.append(graph.horse)

        try DomainGraphValidator.save(graph.context)
    }

    @Test
    func mixedClientVisitSupportsOneInvoicePerClientPortion() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let firstClient = Client(name: "Alex")
        let secondClient = Client(name: "Jordan")
        let barn = Barn(name: "North Field")
        context.insert(firstClient)
        context.insert(secondClient)
        context.insert(barn)
        let firstHorse = Horse(name: "Milo", client: firstClient, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: secondClient, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        firstClient.horses.append(firstHorse)
        secondClient.horses.append(secondHorse)
        barn.horses.append(contentsOf: [firstHorse, secondHorse])
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [firstHorse, secondHorse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: context
        )
        let visitHorses = Dictionary(
            uniqueKeysWithValues: try visit.visitHorses.map { visitHorse in
                let horse = try #require(visitHorse.horse)
                visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
                return (horse.name, visitHorse)
            }
        )
        let firstService = ModelFixtures.makeService(name: "Trim", in: context)
        let secondService = ModelFixtures.makeService(name: "Front Shoes", in: context)
        let firstWorkItem = ModelFixtures.makeWorkItem(
            service: firstService,
            visitHorse: try #require(visitHorses["Milo"]),
            in: context
        )
        let secondWorkItem = ModelFixtures.makeWorkItem(
            service: secondService,
            visitHorse: try #require(visitHorses["Scout"]),
            in: context
        )
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 3, in: context)
        let firstInvoice = ModelFixtures.makeInvoice(
            number: 1,
            client: firstClient,
            businessProfile: profile,
            in: context
        )
        let secondInvoice = ModelFixtures.makeInvoice(
            number: 2,
            client: secondClient,
            businessProfile: profile,
            in: context
        )
        let firstInvoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: firstInvoice,
            sourceVisit: visit,
            in: context
        )
        let secondInvoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: secondInvoice,
            sourceVisit: visit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: firstInvoiceVisit,
            sourceWorkItem: firstWorkItem,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: secondInvoiceVisit,
            sourceWorkItem: secondWorkItem,
            in: context
        )

        try DomainGraphValidator.validateAll(in: context)

        #expect(visit.invoiceVisits.count == 2)
        #expect(firstInvoiceVisit.sourceVisit === secondInvoiceVisit.sourceVisit)
        #expect(firstWorkItem.invoiceLineItem?.invoiceVisit?.invoice === firstInvoice)
        #expect(secondWorkItem.invoiceLineItem?.invoiceVisit?.invoice === secondInvoice)
    }

    @Test
    func invoiceLineMustBelongToTheInvoicesClient() throws {
        let graph = try makeGraph()
        let otherClient = Client(name: "Jordan")
        let otherHorse = Horse(
            name: "Scout",
            client: otherClient,
            currentBarn: graph.barn
        )
        graph.context.insert(otherClient)
        graph.context.insert(otherHorse)
        otherClient.horses.append(otherHorse)
        graph.barn.horses.append(otherHorse)
        let otherAppointmentHorse = AppointmentHorse(
            appointment: graph.appointment,
            horse: otherHorse
        )
        graph.context.insert(otherAppointmentHorse)
        graph.appointment.appointmentHorses.append(otherAppointmentHorse)
        otherHorse.appointmentHorses.append(otherAppointmentHorse)
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        for visitHorse in visit.visitHorses {
            visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        }
        let service = ModelFixtures.makeService(in: graph.context)
        let otherVisitHorse = try #require(
            visit.visitHorses.first { $0.horse === otherHorse }
        )
        let otherWorkItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: otherVisitHorse,
            in: graph.context
        )
        let firstVisitHorse = try #require(
            visit.visitHorses.first { $0.horse === graph.horse }
        )
        let firstService = ModelFixtures.makeService(name: "Trim", in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: firstService,
            visitHorse: firstVisitHorse,
            in: graph.context
        )
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 2, in: graph.context)
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: graph.client,
            businessProfile: profile,
            in: graph.context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: graph.context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: otherWorkItem,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.invoiceLineItemClientMismatch) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func invoiceRejectsDuplicateSourceVisitWithinOneInvoice() throws {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let firstService = ModelFixtures.makeService(name: "Trim", in: graph.context)
        let secondService = ModelFixtures.makeService(name: "Front Shoes", in: graph.context)
        let firstWorkItem = ModelFixtures.makeWorkItem(
            service: firstService,
            visitHorse: visitHorse,
            in: graph.context
        )
        let secondWorkItem = ModelFixtures.makeWorkItem(
            service: secondService,
            visitHorse: visitHorse,
            in: graph.context
        )
        let profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 2, in: graph.context)
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: graph.client,
            businessProfile: profile,
            in: graph.context
        )
        let firstGroup = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: graph.context
        )
        let secondGroup = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: graph.context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: firstGroup,
            sourceWorkItem: firstWorkItem,
            in: graph.context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: secondGroup,
            sourceWorkItem: secondWorkItem,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.duplicateInvoiceVisitSource) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func invoiceSequenceMustRemainAheadOfEveryIssuedNumber() throws {
        let graph = try makeValidInvoiceGraph(number: 4, nextInvoiceNumber: 4)

        #expect(throws: DomainGraphViolation.businessProfileSequenceInvalid) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func invoiceNumbersMustBeUnique() throws {
        let graph = try makeValidInvoiceGraph(number: 1, nextInvoiceNumber: 2)
        let client = try #require(graph.invoice.client)
        let duplicate = Invoice(
            number: 1,
            invoiceDate: Date(timeIntervalSinceReferenceDate: 700),
            clientNameSnapshot: client.name,
            businessNameSnapshot: "Alex Carter Farrier",
            client: client
        )
        graph.context.insert(duplicate)
        client.invoices.append(duplicate)

        #expect(throws: DomainGraphViolation.duplicateInvoiceNumber) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func graphRejectsASecondBusinessProfile() throws {
        let graph = try makeGraph()
        _ = ModelFixtures.makeBusinessProfile(name: "First", in: graph.context)
        _ = ModelFixtures.makeBusinessProfile(name: "Second", in: graph.context)

        #expect(throws: DomainGraphViolation.duplicateBusinessProfile) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func invoiceTotalOverflowFailsClosed() throws {
        let graph = try makeValidInvoiceGraph(
            lineAmounts: [Int64.max, 1],
            nextInvoiceNumber: 2
        )

        #expect(throws: DomainGraphViolation.invoiceTotalOverflow) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    private func makeGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        client: Client,
        barn: Barn,
        horse: Horse,
        appointment: Appointment,
        appointmentHorse: AppointmentHorse
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        try context.save()
        let appointmentHorse = try #require(appointment.appointmentHorses.first)
        return (container, context, client, barn, horse, appointment, appointmentHorse)
    }

    private func makeValidInvoiceGraph(
        number: Int64 = 1,
        lineAmounts: [Int64] = [7_500],
        nextInvoiceNumber: Int64
    ) throws -> (
        container: ModelContainer,
        context: ModelContext,
        invoice: Invoice
    ) {
        let graph = try makeGraph()
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: graph.appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let profile = ModelFixtures.makeBusinessProfile(
            nextInvoiceNumber: nextInvoiceNumber,
            in: graph.context
        )
        let invoice = ModelFixtures.makeInvoice(
            number: number,
            client: graph.client,
            businessProfile: profile,
            in: graph.context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: graph.context
        )
        for (index, amount) in lineAmounts.enumerated() {
            let service = ModelFixtures.makeService(
                name: "Service \(index)",
                defaultAmountMinorUnits: amount,
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
        return (graph.container, graph.context, invoice)
    }
}
