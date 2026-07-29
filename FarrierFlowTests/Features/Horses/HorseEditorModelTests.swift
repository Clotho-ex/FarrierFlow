import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Horse default Service editor")
@MainActor
struct HorseEditorModelTests {
    @Test
    func loadsOnlyActiveValidServiceChoices() throws {
        let graph = try makeHorseGraph()
        let active = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 7_500, in: graph.context)
        _ = ModelFixtures.makeService(name: "Archived", isArchived: true, in: graph.context)
        let invalid = Service(name: "Invalid", defaultAmountMinorUnits: -1)
        graph.context.insert(invalid)
        try graph.context.save()

        let editor = HorseEditorModel(horse: graph.horse)
        editor.loadChoices(in: graph.context)

        #expect(editor.choicesLoadState == .loaded)
        #expect(editor.activeServiceChoices.map(\.id) == [active.persistentModelID])
        #expect(editor.activeServiceChoices.first?.name == "Trim")
        #expect(editor.activeServiceChoices.first?.defaultAmountMinorUnits == 7_500)
    }

    @Test
    func savesAnActiveDefaultAndNoneClearsIt() throws {
        let graph = try makeHorseGraph()
        let service = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 7_500, in: graph.context)
        try DomainGraphValidator.save(graph.context)

        let editor = HorseEditorModel(horse: graph.horse)
        editor.loadChoices(in: graph.context)
        editor.draft.defaultServiceID = service.persistentModelID
        #expect(editor.save(in: graph.context) == graph.horse.persistentModelID)
        #expect(graph.horse.defaultService === service)
        #expect(service.horsesUsingAsDefault.contains { $0 === graph.horse })

        let clearEditor = HorseEditorModel(horse: graph.horse)
        clearEditor.loadChoices(in: graph.context)
        clearEditor.draft.defaultServiceID = nil
        #expect(clearEditor.save(in: graph.context) == graph.horse.persistentModelID)
        #expect(graph.horse.defaultService == nil)
        #expect(!service.horsesUsingAsDefault.contains { $0 === graph.horse })
    }

    @Test
    func archivedOrMissingDefaultSelectionFailsClosedWithoutChangingHorse() throws {
        let graph = try makeHorseGraph()
        let archived = ModelFixtures.makeService(name: "Archived", isArchived: true, in: graph.context)
        try DomainGraphValidator.save(graph.context)

        let editor = HorseEditorModel(horse: graph.horse)
        editor.loadChoices(in: graph.context)
        editor.draft.defaultServiceID = archived.persistentModelID

        #expect(!editor.canSave)
        #expect(editor.save(in: graph.context) == nil)
        #expect(graph.horse.defaultService == nil)
    }

    @Test
    func failedDefaultSaveRollsBackTheRelationshipAndPreservesDraft() throws {
        let graph = try makeHorseGraph()
        let service = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 7_500, in: graph.context)
        try DomainGraphValidator.save(graph.context)
        let horseID = graph.horse.persistentModelID

        let editor = HorseEditorModel(horse: graph.horse)
        editor.loadChoices(in: graph.context)
        editor.draft.defaultServiceID = service.persistentModelID
        graph.context.insert(Service(name: "Invalid", defaultAmountMinorUnits: -1))

        #expect(editor.save(in: graph.context) == nil)
        #expect(editor.draft.defaultServiceID == service.persistentModelID)
        let verificationContext = ModelContext(graph.container)
        let reloadedHorse = try #require(verificationContext.model(for: horseID) as? Horse)
        #expect(reloadedHorse.defaultService == nil)
        #expect(try verificationContext.fetchCount(FetchDescriptor<Service>()) == 1)

        let client = try #require(reloadedHorse.client)
        client.notes = "Unrelated later edit"
        try DomainGraphValidator.save(verificationContext)

        let reopenedContext = ModelContext(graph.container)
        let reopenedHorse = try #require(reopenedContext.model(for: horseID) as? Horse)
        #expect(reopenedHorse.defaultService == nil)
    }

    @Test
    func changingDefaultLeavesExistingAppointmentVisitAndWorkHistoryUntouched() throws {
        let graph = try makeHorseGraph()
        let service = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 7_500, in: graph.context)
        let appointment = ModelFixtures.makeAppointment(
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            barn: graph.barn,
            horses: [graph.horse],
            in: graph.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: graph.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        try DomainGraphValidator.save(graph.context)
        let appointmentID = appointment.persistentModelID
        let visitID = visit.persistentModelID
        let startedAt = visit.startedAt
        let completedAt = visit.completedAt

        let editor = HorseEditorModel(horse: graph.horse)
        editor.loadChoices(in: graph.context)
        editor.draft.defaultServiceID = service.persistentModelID
        #expect(editor.save(in: graph.context) == graph.horse.persistentModelID)

        #expect(appointment.persistentModelID == appointmentID)
        #expect(visit.persistentModelID == visitID)
        #expect(visit.startedAt == startedAt)
        #expect(visit.completedAt == completedAt)
        #expect(visit.visitHorses.count == 1)
        #expect(visitHorse.workItems.isEmpty)
    }

    private func makeHorseGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        client: Client,
        barn: Barn,
        horse: Horse
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        return (container, context, client, barn, horse)
    }
}
