import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Record deletion rules")
@MainActor
struct RecordDeletionRulesTests {
    @Test
    func referencedClientBarnAndHorseAreBlocked() throws {
        let graph = try makeGraph()

        #expect(throws: RecordDeletionBlock.clientHasHorses) {
            try RecordDeletionRules.delete(graph.client, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.barnHasHorsesAndAppointments) {
            try RecordDeletionRules.delete(graph.barn, in: graph.context)
        }
        #expect(throws: RecordDeletionBlock.horseHasAppointments) {
            try RecordDeletionRules.delete(graph.horse, in: graph.context)
        }
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
    }

    @Test
    func deletingAppointmentCascadesOnlyItsJoin() throws {
        let graph = try makeGraph()
        try RecordDeletionRules.delete(graph.appointment, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 1)
    }

    @Test
    func deletingAppointmentHorseRemovesOnlyThatMembership() throws {
        let graph = try makeGraph()
        let secondClient = Client(name: "Jordan")
        graph.context.insert(secondClient)
        let secondHorse = Horse(
            name: "Scout",
            client: secondClient,
            currentBarn: graph.barn
        )
        graph.context.insert(secondHorse)
        secondClient.horses.append(secondHorse)
        graph.barn.horses.append(secondHorse)
        let appointmentHorse = AppointmentHorse(
            appointment: graph.appointment,
            horse: secondHorse
        )
        graph.context.insert(appointmentHorse)
        graph.appointment.appointmentHorses.append(appointmentHorse)
        secondHorse.appointmentHorses.append(appointmentHorse)
        try graph.context.save()

        try RecordDeletionRules.delete(appointmentHorse, in: graph.context)

        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Client>()) == 2)
        #expect(try graph.context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try graph.context.fetchCount(FetchDescriptor<Horse>()) == 2)
        #expect(graph.appointment.appointmentHorses.first?.horse === graph.horse)
    }

    @Test
    func emptyRecordsCanBeDeleted() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Empty Client")
        let barn = Barn(name: "Empty Barn")
        context.insert(client)
        context.insert(barn)
        try context.save()
        try RecordDeletionRules.delete(client, in: context)
        try RecordDeletionRules.delete(barn, in: context)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 0)
    }

    private func makeGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        client: Client,
        barn: Barn,
        horse: Horse,
        appointment: Appointment
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
        return (container, context, client, barn, horse, appointment)
    }
}
