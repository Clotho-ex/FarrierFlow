import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Appointment editor model")
@MainActor
struct AppointmentEditorModelTests {
    @Test
    func createsOneBarnStopForHorsesFromMultipleClients() throws {
        let fixture = try makeTwoHorseFixture()
        let editor = AppointmentEditorModel()
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.horses[0].persistentModelID)
        editor.toggleHorse(fixture.horses[1].persistentModelID)

        let id = try #require(editor.save(in: fixture.context))
        let appointment = try #require(fixture.context.model(for: id) as? Appointment)
        #expect(appointment.appointmentHorses.count == 2)
        #expect(
            Set(appointment.appointmentHorses.compactMap(\.horse?.client?.name))
                == ["Alex", "Jordan"]
        )
        #expect(appointment.expectedDurationMinutes == nil)
    }

    @Test
    func changingBarnClearsIneligibleSelection() throws {
        let fixture = try makeTwoHorseFixture()
        let otherBarn = Barn(name: "South Field")
        fixture.context.insert(otherBarn)
        try fixture.context.save()
        let editor = AppointmentEditorModel()
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.horses[0].persistentModelID)

        editor.selectBarn(otherBarn.persistentModelID, in: fixture.context)
        #expect(editor.draft.selectedHorseIDs.isEmpty)
    }

    private func makeTwoHorseFixture() throws -> (
        container: ModelContainer,
        context: ModelContext,
        barn: Barn,
        horses: [Horse]
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let barn = Barn(name: "North Field")
        let firstClient = Client(name: "Alex")
        let secondClient = Client(name: "Jordan")
        context.insert(barn)
        context.insert(firstClient)
        context.insert(secondClient)
        let firstHorse = Horse(name: "Milo", client: firstClient, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: secondClient, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        firstClient.horses.append(firstHorse)
        secondClient.horses.append(secondHorse)
        barn.horses.append(contentsOf: [firstHorse, secondHorse])
        try context.save()
        return (container, context, barn, [firstHorse, secondHorse])
    }
}
