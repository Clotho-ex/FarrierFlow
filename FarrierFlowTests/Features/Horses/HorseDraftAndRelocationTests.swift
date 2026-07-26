import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Horse drafts and relocation")
@MainActor
struct HorseDraftAndRelocationTests {
    @Test
    func draftRequiresNameClientBarnAndPositiveInterval() {
        var draft = HorseDraft(name: "Milo")
        #expect(!draft.isValid)
        draft.appointmentIntervalWeeks = 0
        #expect(!draft.isValid)
    }

    @Test
    func relocationRuleAllowsNoOpAndUnreferencedMove() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let first = Barn(name: "First")
        let second = Barn(name: "Second")
        context.insert(first)
        context.insert(second)
        try context.save()

        #expect(HorseRelocationRules.canRelocate(
            appointmentMembershipCount: 1,
            currentBarnID: first.persistentModelID,
            destinationBarnID: first.persistentModelID
        ))
        #expect(HorseRelocationRules.canRelocate(
            appointmentMembershipCount: 0,
            currentBarnID: first.persistentModelID,
            destinationBarnID: second.persistentModelID
        ))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentMembershipCount: 1,
            currentBarnID: first.persistentModelID,
            destinationBarnID: second.persistentModelID
        ))
    }

    @Test
    func blockedEditorMoveLeavesAppointmentGraphUnchanged() throws {
        let graph = try makeReferencedHorseGraph()
        let originalBarn = graph.horse.currentBarn
        let appointmentCount = try graph.context.fetchCount(FetchDescriptor<Appointment>())
        let joinCount = try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>())
        let destination = Barn(name: "South Field")
        graph.context.insert(destination)
        try graph.context.save()

        let editor = HorseEditorModel(horse: graph.horse)
        editor.draft.barnID = destination.persistentModelID
        #expect(editor.save(in: graph.context) == nil)
        #expect(graph.horse.currentBarn === originalBarn)
        #expect(try graph.context.fetchCount(FetchDescriptor<Appointment>()) == appointmentCount)
        #expect(try graph.context.fetchCount(FetchDescriptor<AppointmentHorse>()) == joinCount)
    }

    private func makeReferencedHorseGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        horse: Horse
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
        _ = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        try context.save()
        return (container, context, horse)
    }
}
