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
    func relocationRuleUsesTheFullVisitStateMatrix() {
        #expect(HorseRelocationRules.canRelocate(
            appointmentStates: [.noVisit],
            hasInProgressVisitHorse: true,
            isSameBarn: true
        ))
        #expect(HorseRelocationRules.canRelocate(
            appointmentStates: [],
            hasInProgressVisitHorse: false,
            isSameBarn: false
        ))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentStates: [.noVisit],
            hasInProgressVisitHorse: false,
            isSameBarn: false
        ))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentStates: [.inProgress],
            hasInProgressVisitHorse: false,
            isSameBarn: false
        ))
        #expect(HorseRelocationRules.canRelocate(
            appointmentStates: [.completed],
            hasInProgressVisitHorse: false,
            isSameBarn: false
        ))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentStates: [.completed, .noVisit],
            hasInProgressVisitHorse: false,
            isSameBarn: false
        ))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentStates: [.invalid],
            hasInProgressVisitHorse: false,
            isSameBarn: false
        ))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentStates: [.completed],
            hasInProgressVisitHorse: true,
            isSameBarn: false
        ))
    }

    @Test
    func malformedCompletedVisitGraphsFailClosedForProjectionAndPicker() throws {
        try assertMalformedCompletedGraphBlocksRelocation { appointment, _, _, _, _ in
            appointment.barn = nil
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, _, _, _ in
            visit.barn = nil
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, _, _, context in
            let otherBarn = Barn(name: "Mismatched Barn")
            context.insert(otherBarn)
            visit.barn = otherBarn
            otherBarn.visits.append(visit)
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, _, _, context in
            let client = try #require(visit.visitHorses.first?.horse?.client)
            let barn = try #require(visit.visitHorses.first?.horse?.currentBarn)
            let replacement = Horse(name: "Replacement", client: client, currentBarn: barn)
            context.insert(replacement)
            client.horses.append(replacement)
            barn.horses.append(replacement)
            let membership = try #require(visit.visitHorses.first)
            membership.horse = replacement
            replacement.visitHorses.append(membership)
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, horse, _, context in
            let duplicate = VisitHorse(visit: visit, horse: horse)
            context.insert(duplicate)
            visit.visitHorses.append(duplicate)
            horse.visitHorses.append(duplicate)
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, _, _, _ in
            visit.visitHorses[0].outcomeRawValue = VisitOutcome.pending.rawValue
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, _, _, _ in
            visit.visitHorses[0].outcomeRawValue = VisitOutcome.notServiced.rawValue
            visit.visitHorses[0].workNotes = "Invalid notes"
        }
        try assertMalformedCompletedGraphBlocksRelocation { _, visit, _, _, _ in
            visit.completedAt = Date(timeIntervalSinceReferenceDate: 99)
        }
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
            context.insert(client)
            context.insert(originalBarn)
            context.insert(destinationBarn)
            context.insert(horse)
            client.horses.append(horse)
            originalBarn.horses.append(horse)
            let completedAppointment = ModelFixtures.makeAppointment(
                barn: originalBarn,
                horses: [horse],
                in: context
            )
            try DomainGraphValidator.save(context)
            let clientID = client.persistentModelID
            let horseID = horse.persistentModelID
            let originalBarnID = originalBarn.persistentModelID
            let destinationBarnID = destinationBarn.persistentModelID
            let completedAppointmentID = completedAppointment.persistentModelID

            let completedVisitID = try VisitStartUseCase.start(
                appointmentID: completedAppointmentID,
                now: Date(timeIntervalSinceReferenceDate: 100),
                in: container
            )
            let visitContext = ModelContext(container)
            var completedDraft = try VisitSaveUseCase.loadDraft(
                visitID: completedVisitID,
                in: visitContext
            )
            let miloIndex = try #require(
                completedDraft.horses.firstIndex(where: { $0.horseName == "Milo" })
            )
            completedDraft.horses[miloIndex].outcome = .serviced
            completedDraft.horses[miloIndex].workNotes = "Completed work"
            _ = try VisitSaveUseCase.complete(
                draft: completedDraft,
                completedAt: Date(timeIntervalSinceReferenceDate: 200),
                in: visitContext
            )

            let relocationContext = ModelContext(container)
            let relocationHorse = try #require(
                relocationContext.model(for: horseID) as? Horse
            )
            let relocationOriginalBarn = try #require(
                relocationContext.model(for: originalBarnID) as? Barn
            )
            let relocationDestinationBarn = try #require(
                relocationContext.model(for: destinationBarnID) as? Barn
            )
            let relocationCompletedAppointment = try #require(
                relocationContext.model(for: completedAppointmentID) as? Appointment
            )
            let completedMembership = try #require(
                relocationCompletedAppointment.appointmentHorses.first
            )
            #expect(
                HorseRelocationRules.appointmentVisitState(for: completedMembership) == .completed
            )

            let picker = ExistingHorsePickerModel()
            picker.load(destinationBarnID: destinationBarnID, in: relocationContext)
            #expect(picker.horses.map(\.name) == ["Milo"])

            let unresolvedAppointment = ModelFixtures.makeAppointment(
                startDate: Date(timeIntervalSinceReferenceDate: -86_400),
                barn: relocationOriginalBarn,
                horses: [relocationHorse],
                in: relocationContext
            )
            try DomainGraphValidator.save(relocationContext)
            let unresolvedMembership = try #require(
                unresolvedAppointment.appointmentHorses.first
            )
            #expect(
                HorseRelocationRules.appointmentVisitState(for: unresolvedMembership) == .noVisit
            )
            picker.load(destinationBarnID: destinationBarnID, in: relocationContext)
            #expect(picker.horses.isEmpty)

            try RecordDeletionRules.delete(unresolvedAppointment, in: relocationContext)
            picker.load(destinationBarnID: destinationBarnID, in: relocationContext)
            #expect(picker.horses.map(\.name) == ["Milo"])

            let completedMembershipID = completedMembership.persistentModelID
            let visitSnapshotName = try #require(
                (relocationContext.model(for: completedVisitID) as? Visit)?.serviceLocationNameSnapshot
            )
            var observedRelocationBeforeFailure = false
            let failingPicker = ExistingHorsePickerModel(
                saving: { _ in
                    observedRelocationBeforeFailure = relocationHorse.currentBarn === relocationDestinationBarn
                    throw ForcedFetchFailure.unavailable
                }
            )
            failingPicker.selectedHorseID = horseID

            #expect(!failingPicker.move(
                to: destinationBarnID,
                in: relocationContext
            ))
            #expect(observedRelocationBeforeFailure)
            #expect(relocationHorse.currentBarn === relocationOriginalBarn)
            #expect(relocationCompletedAppointment.persistentModelID == completedAppointmentID)
            #expect(relocationCompletedAppointment.appointmentHorses.first?.persistentModelID == completedMembershipID)
            #expect(relocationCompletedAppointment.appointmentHorses.first?.horse === relocationHorse)
            let visit = try #require(relocationContext.model(for: completedVisitID) as? Visit)
            #expect(visit.startedAt == Date(timeIntervalSinceReferenceDate: 100))
            #expect(visit.completedAt == Date(timeIntervalSinceReferenceDate: 200))
            #expect(visit.serviceLocationNameSnapshot == visitSnapshotName)
            #expect(visit.visitHorses.count == 1)
            #expect(visit.visitHorses.first?.horse === relocationHorse)
            let relocationClient = try #require(
                relocationContext.model(for: clientID) as? Client
            )
            relocationClient.notes = "Unrelated later edit"
            try DomainGraphValidator.save(relocationContext)
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
            #expect(membership.horse?.name == "Milo")
            let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)
            #expect(visit.startedAt == Date(timeIntervalSinceReferenceDate: 100))
            #expect(visit.completedAt == Date(timeIntervalSinceReferenceDate: 200))
            #expect(visit.serviceLocationNameSnapshot == "Barn A")
            #expect(visit.visitHorses.count == 1)
            #expect(visit.visitHorses.first?.horse?.name == "Milo")
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

    private func assertMalformedCompletedGraphBlocksRelocation(
        mutation: (Appointment, Visit, Horse, Barn, ModelContext) throws -> Void
    ) throws {
        let graph = try makeCompletedRelocationGraph()
        let context = ModelContext(graph.container)
        let horse = try #require(context.model(for: graph.horseID) as? Horse)
        let appointment = try #require(context.model(for: graph.appointmentID) as? Appointment)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        let destination = try #require(context.model(for: graph.destinationBarnID) as? Barn)
        try mutation(appointment, visit, horse, destination, context)
        try context.save()

        let projection = try #require(
            HorseRelocationRules.projection(for: horse, destinationBarnID: destination.persistentModelID)
        )
        #expect(projection.appointmentStates.contains(.invalid))
        #expect(!HorseRelocationRules.canRelocate(
            appointmentStates: projection.appointmentStates,
            hasInProgressVisitHorse: projection.hasInProgressVisitHorse,
            isSameBarn: projection.isSameBarn
        ))

        let picker = ExistingHorsePickerModel()
        picker.load(destinationBarnID: destination.persistentModelID, in: context)
        #expect(picker.horses.isEmpty)
    }

    private func makeCompletedRelocationGraph() throws -> (
        container: ModelContainer,
        horseID: PersistentIdentifier,
        appointmentID: PersistentIdentifier,
        visitID: PersistentIdentifier,
        destinationBarnID: PersistentIdentifier
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let source = Barn(name: "Barn A")
        let destination = Barn(name: "Barn B")
        let horse = Horse(name: "Milo", client: client, currentBarn: source)
        context.insert(client)
        context.insert(source)
        context.insert(destination)
        context.insert(horse)
        client.horses.append(horse)
        source.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(barn: source, horses: [horse], in: context)
        try DomainGraphValidator.save(context)
        let visitID = try VisitStartUseCase.start(
            appointmentID: appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 100),
            in: container
        )
        let completionContext = ModelContext(container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visitID, in: completionContext)
        let miloIndex = try #require(draft.horses.firstIndex(where: { $0.horseName == "Milo" }))
        draft.horses[miloIndex].outcome = .serviced
        _ = try VisitSaveUseCase.complete(
            draft: draft,
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            in: completionContext
        )
        return (
            container,
            horse.persistentModelID,
            appointment.persistentModelID,
            visitID,
            destination.persistentModelID
        )
    }
}
