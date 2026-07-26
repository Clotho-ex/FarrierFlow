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

    private func makeGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
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
        return (container, context, horse, appointment, appointmentHorse)
    }
}
