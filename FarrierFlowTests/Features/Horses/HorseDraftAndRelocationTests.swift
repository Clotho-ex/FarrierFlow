import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Horse drafts and relocation")
@MainActor
struct HorseDraftAndRelocationTests {
    private enum ForcedFetchFailure: Error {
        case unavailable
    }

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

    @Test
    func editorChoiceLoadPublishesRecords() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "Barn A")
        context.insert(client)
        context.insert(barn)
        try context.save()

        let editor = HorseEditorModel()
        editor.loadChoices(in: context)

        #expect(editor.choicesLoadState == .loaded)
        #expect(editor.clients.map(\.name) == ["Alex"])
        #expect(editor.barns.map(\.name) == ["Barn A"])
    }

    @Test
    func editorChoiceLoadPublishesLegitimateEmptyResult() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let editor = HorseEditorModel()

        editor.loadChoices(in: container.mainContext)

        #expect(editor.choicesLoadState == .loaded)
        #expect(editor.clients.isEmpty)
        #expect(editor.barns.isEmpty)
    }

    @Test
    func editorChoiceLoadFailurePreservesRecordsAndDraft() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "Barn A")
        context.insert(client)
        context.insert(barn)
        try context.save()
        var shouldFail = false
        let editor = HorseEditorModel(
            clientFetcher: { context in
                if shouldFail { throw ForcedFetchFailure.unavailable }
                return try context.fetch(FetchDescriptor<Client>())
            },
            barnFetcher: { context in
                if shouldFail { throw ForcedFetchFailure.unavailable }
                return try context.fetch(FetchDescriptor<Barn>())
            }
        )
        editor.draft.name = "Draft name"
        editor.loadChoices(in: context)

        shouldFail = true
        editor.loadChoices(in: context)

        #expect(editor.choicesLoadState == .failed)
        #expect(editor.clients.map(\.name) == ["Alex"])
        #expect(editor.barns.map(\.name) == ["Barn A"])
        #expect(editor.draft.name == "Draft name")
    }

    @Test
    func pickerFetchFailurePreservesPreviouslyLoadedHorses() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let originalBarn = Barn(name: "Barn A")
        let destinationBarn = Barn(name: "Barn B")
        let horse = Horse(name: "Milo", client: client, currentBarn: originalBarn)
        context.insert(client)
        context.insert(originalBarn)
        context.insert(destinationBarn)
        context.insert(horse)
        client.horses.append(horse)
        originalBarn.horses.append(horse)
        try context.save()
        var shouldFail = false
        let picker = ExistingHorsePickerModel { context in
            if shouldFail { throw ForcedFetchFailure.unavailable }
            return try context.fetch(FetchDescriptor<Horse>())
        }

        picker.load(
            destinationBarnID: destinationBarn.persistentModelID,
            in: context
        )
        shouldFail = true
        picker.load(
            destinationBarnID: destinationBarn.persistentModelID,
            in: context
        )

        #expect(picker.loadState == .failed)
        #expect(picker.horses.map(\.name) == ["Milo"])
    }

    @Test
    func failedPickerRelocationDoesNotLeakIntoALaterSaveOrStoreReopen() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Failed-Relocation-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let client = Client(name: "Alex")
            let originalBarn = Barn(name: "Barn A")
            let destinationBarn = Barn(name: "Barn B")
            let horse = Horse(name: "Milo", client: client, currentBarn: originalBarn)
            let scheduledHorse = Horse(
                name: "Scout",
                client: client,
                currentBarn: originalBarn
            )
            context.insert(client)
            context.insert(originalBarn)
            context.insert(destinationBarn)
            context.insert(horse)
            context.insert(scheduledHorse)
            client.horses.append(contentsOf: [horse, scheduledHorse])
            originalBarn.horses.append(contentsOf: [horse, scheduledHorse])
            let appointment = ModelFixtures.makeAppointment(
                barn: originalBarn,
                horses: [scheduledHorse],
                in: context
            )
            try DomainGraphValidator.save(context)

            let appointmentID = appointment.persistentModelID
            let membershipID = try #require(
                appointment.appointmentHorses.first?.persistentModelID
            )
            let invalidHorse = Horse(
                name: "Unsaved invalid graph",
                client: client,
                currentBarn: originalBarn
            )
            context.insert(invalidHorse)
            invalidHorse.client = nil
            invalidHorse.currentBarn = nil

            let picker = ExistingHorsePickerModel()
            picker.selectedHorseID = horse.persistentModelID

            #expect(!picker.move(
                to: destinationBarn.persistentModelID,
                in: context
            ))
            #expect(horse.currentBarn === originalBarn)
            #expect(appointment.persistentModelID == appointmentID)
            #expect(appointment.appointmentHorses.count == 1)
            #expect(appointment.appointmentHorses.first?.persistentModelID == membershipID)
            #expect(appointment.appointmentHorses.first?.horse === scheduledHorse)

            invalidHorse.client = client
            invalidHorse.currentBarn = originalBarn
            client.horses.append(invalidHorse)
            originalBarn.horses.append(invalidHorse)
            client.notes = "Unrelated later edit"
            try DomainGraphValidator.save(context)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let horse = try #require(
                context.fetch(FetchDescriptor<Horse>())
                    .first { $0.name == "Milo" }
            )
            let appointment = try #require(
                context.fetch(FetchDescriptor<Appointment>()).first
            )
            let membership = try #require(
                context.fetch(FetchDescriptor<AppointmentHorse>()).first
            )

            #expect(horse.currentBarn?.name == "Barn A")
            #expect(appointment.barn?.name == "Barn A")
            #expect(appointment.appointmentHorses.count == 1)
            #expect(membership.horse?.name == "Scout")
            try DomainGraphValidator.validateAll(in: context)
        }
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
