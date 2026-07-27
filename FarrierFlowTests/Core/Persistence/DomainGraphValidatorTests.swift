import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Domain graph validation")
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
        let otherBarn = Barn(name: "South Field")
        graph.context.insert(otherBarn)
        graph.horse.currentBarn = otherBarn
        otherBarn.horses.append(graph.horse)

        try DomainGraphValidator.save(graph.context)
    }

    private func makeGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
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
        return (container, context, barn, horse, appointment, appointmentHorse)
    }
}
