import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("SwiftData relationship insertion")
@MainActor
struct SwiftDataRelationshipInsertionTests {
    @Test
    func explicitlyConnectingBothSidesPersistsRequiredRelationships() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        context.insert(client)
        context.insert(barn)

        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let appointment = Appointment(startDate: .now, barn: barn)
        context.insert(appointment)
        barn.appointments.append(appointment)

        let appointmentHorse = AppointmentHorse(
            appointment: appointment,
            horse: horse
        )
        context.insert(appointmentHorse)
        appointment.appointmentHorses.append(appointmentHorse)
        horse.appointmentHorses.append(appointmentHorse)

        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
        #expect(horse.client === client)
        #expect(horse.currentBarn === barn)
        #expect(appointment.barn === barn)
        #expect(appointmentHorse.appointment === appointment)
        #expect(appointmentHorse.horse === horse)
    }
}
