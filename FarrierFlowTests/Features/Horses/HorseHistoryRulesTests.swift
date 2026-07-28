import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Horse history")
@MainActor
struct HorseHistoryRulesTests {
    @Test
    func completedHistoryUsesTheApprovedFourLevelOrderAndExcludesInProgressVisits() throws {
        let identifiers = try makeIdentifiers(count: 12)
        let sources = [
            HorseHistoryRecord(
                id: identifiers[0],
                visitID: identifiers[1],
                horseID: identifiers[2],
                horseName: "Zelda",
                startedAt: Date(timeIntervalSinceReferenceDate: 500),
                completedAt: Date(timeIntervalSinceReferenceDate: 500),
                serviceLocationName: "Zeta Barn",
                outcomeRawValue: VisitOutcome.serviced.rawValue,
                workNotes: nil
            ),
            HorseHistoryRecord(
                id: identifiers[3],
                visitID: identifiers[4],
                horseID: identifiers[5],
                horseName: "Zelda",
                startedAt: Date(timeIntervalSinceReferenceDate: 400),
                completedAt: Date(timeIntervalSinceReferenceDate: 500),
                serviceLocationName: "Zeta Barn",
                outcomeRawValue: VisitOutcome.notServiced.rawValue,
                workNotes: nil
            ),
            HorseHistoryRecord(
                id: identifiers[6],
                visitID: identifiers[7],
                horseID: identifiers[8],
                horseName: "Zelda",
                startedAt: Date(timeIntervalSinceReferenceDate: 400),
                completedAt: Date(timeIntervalSinceReferenceDate: 400),
                serviceLocationName: "Zeta Barn",
                outcomeRawValue: VisitOutcome.serviced.rawValue,
                workNotes: "Trimmed"
            ),
            HorseHistoryRecord(
                id: identifiers[9],
                visitID: identifiers[10],
                horseID: identifiers[11],
                horseName: "Scout",
                startedAt: Date(timeIntervalSinceReferenceDate: 400),
                completedAt: Date(timeIntervalSinceReferenceDate: 400),
                serviceLocationName: "Alpha Barn",
                outcomeRawValue: VisitOutcome.notServiced.rawValue,
                workNotes: nil
            ),
            HorseHistoryRecord(
                id: identifiers[10],
                visitID: identifiers[11],
                horseID: identifiers[9],
                horseName: "Milo",
                startedAt: Date(timeIntervalSinceReferenceDate: 400),
                completedAt: Date(timeIntervalSinceReferenceDate: 400),
                serviceLocationName: "Alpha Barn",
                outcomeRawValue: VisitOutcome.serviced.rawValue,
                workNotes: nil
            ),
            HorseHistoryRecord(
                id: identifiers[11],
                visitID: identifiers[9],
                horseID: identifiers[10],
                horseName: "Pending Horse",
                startedAt: Date(timeIntervalSinceReferenceDate: 600),
                completedAt: nil,
                serviceLocationName: "Future Barn",
                outcomeRawValue: VisitOutcome.pending.rawValue,
                workNotes: nil
            ),
        ]

        let entries = try HorseHistoryRules.entries(
            from: sources,
            locale: Locale(identifier: "en_US")
        )

        #expect(entries.map(\.horseName) == ["Zelda", "Zelda", "Milo", "Scout", "Zelda"])
        #expect(entries.map(\.serviceLocationName) == [
            "Zeta Barn", "Zeta Barn", "Alpha Barn", "Alpha Barn", "Zeta Barn",
        ])
        #expect(entries.map(\.hasWorkNotes) == [false, false, false, false, true])
        #expect(entries.map(\.outcome) == [.serviced, .notServiced, .serviced, .notServiced, .serviced])
    }

    @Test
    func identicalHistoryFieldsUseTheEntryIdentifierAsFinalTieBreak() throws {
        let identifiers = try makeIdentifiers(count: 6).sorted()
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        let completedAt = Date(timeIntervalSinceReferenceDate: 200)
        let records = [
            HorseHistoryRecord(
                id: identifiers[3],
                visitID: identifiers[4],
                horseID: identifiers[5],
                horseName: "Milo",
                startedAt: startedAt,
                completedAt: completedAt,
                serviceLocationName: "North Field",
                outcomeRawValue: VisitOutcome.serviced.rawValue,
                workNotes: nil
            ),
            HorseHistoryRecord(
                id: identifiers[0],
                visitID: identifiers[1],
                horseID: identifiers[2],
                horseName: "Milo",
                startedAt: startedAt,
                completedAt: completedAt,
                serviceLocationName: "North Field",
                outcomeRawValue: VisitOutcome.serviced.rawValue,
                workNotes: nil
            ),
        ]

        let entries = try HorseHistoryRules.entries(
            from: records,
            locale: Locale(identifier: "en_US")
        )

        #expect(entries.map(\.id) == [identifiers[0], identifiers[3]])
    }

    @Test
    func identicalHistoryOrderRemainsStableAcrossStoreReopening() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Horse-History-Order-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")
        var expectedIDs: [PersistentIdentifier] = []
        var firstOrder: [PersistentIdentifier] = []
        var expectedIdentifierKeys: [Data] = []

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = container.mainContext
            let client = Client(name: "Alex")
            let barn = Barn(name: "North Field")
            context.insert(client)
            context.insert(barn)
            let horse = Horse(name: "Milo", client: client, currentBarn: barn)
            context.insert(horse)
            client.horses.append(horse)
            barn.horses.append(horse)

            let firstAppointment = ModelFixtures.makeAppointment(
                barn: barn,
                horses: [horse],
                in: context
            )
            let secondAppointment = ModelFixtures.makeAppointment(
                barn: barn,
                horses: [horse],
                in: context
            )
            let firstVisit = ModelFixtures.makeVisit(
                startedAt: Date(timeIntervalSinceReferenceDate: 100),
                completedAt: Date(timeIntervalSinceReferenceDate: 200),
                appointment: firstAppointment,
                in: context
            )
            let secondVisit = ModelFixtures.makeVisit(
                startedAt: Date(timeIntervalSinceReferenceDate: 100),
                completedAt: Date(timeIntervalSinceReferenceDate: 200),
                appointment: secondAppointment,
                in: context
            )
            firstVisit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
            secondVisit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
            try DomainGraphValidator.save(context)

            let verificationContext = ModelContext(container)
            let storedHorse = try #require(
                verificationContext.fetch(FetchDescriptor<Horse>())
                    .first { $0.name == "Milo" }
            )
            expectedIDs = try verificationContext
                .fetch(FetchDescriptor<VisitHorse>())
                .map(\.persistentModelID)
                .sorted()
            firstOrder = try HorseDetailModel.loadHistory(
                horseID: storedHorse.persistentModelID,
                in: verificationContext,
                locale: Locale(identifier: "en_US")
            ).map(\.id)
            expectedIdentifierKeys = try expectedIDs.map(identifierKey)
            #expect(firstOrder == expectedIDs)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let storedHorseID = try #require(
                context.fetch(FetchDescriptor<Horse>())
                    .first { $0.name == "Milo" }
            ).persistentModelID
            let reopenedOrder = try HorseDetailModel.loadHistory(
                horseID: storedHorseID,
                in: context,
                locale: Locale(identifier: "en_US")
            ).map(\.id)
            let reopenedIdentifierKeys = try reopenedOrder.map(identifierKey)

            #expect(reopenedIdentifierKeys == expectedIdentifierKeys)
        }
    }

    @Test
    func invalidHistoricalRecordsFailClosedInsteadOfDisplayingRawValues() throws {
        let identifiers = try makeIdentifiers(count: 3)
        let invalidSource = HorseHistoryRecord(
            id: identifiers[0],
            visitID: identifiers[1],
            horseID: identifiers[2],
            horseName: "Milo",
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            serviceLocationName: "North Field",
            outcomeRawValue: "unexpected",
            workNotes: nil
        )

        #expect(throws: (any Error).self) {
            try HorseHistoryRules.entries(from: [invalidSource], locale: Locale(identifier: "en_US"))
        }
    }

    @Test
    func loadStatesPreservePriorRowsAfterFailureAndRetry() throws {
        let fixture = try makeHorseFixture()
        let identifiers = try makeIdentifiers(count: 3)
        let entry = HorseHistoryEntry(
            id: identifiers[0],
            visitID: identifiers[1],
            horseName: "Milo",
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            serviceLocationName: "North Field",
            outcome: .serviced,
            hasWorkNotes: true
        )
        var shouldFail = false
        let model = HorseDetailModel(historyLoading: { _, _, _ in
            if shouldFail { throw HorseHistoryTestFailure.unavailable }
            return [entry]
        })

        #expect(model.historyLoadState == .loading)
        model.load(id: fixture.horse.persistentModelID, in: fixture.context)
        #expect(model.historyLoadState == .loaded)
        #expect(model.history == [entry])

        shouldFail = true
        model.load(id: fixture.horse.persistentModelID, in: fixture.context)
        #expect(model.historyLoadState == .failed)
        #expect(model.history == [entry])

        shouldFail = false
        model.retryHistory()
        #expect(model.historyLoadState == .loaded)
        #expect(model.history == [entry])
    }

    @Test
    func emptyHistoryLoadsSuccessfullyAndMissingBarnStillUsesSnapshots() throws {
        let fixture = try makeHorseFixture()
        let emptyModel = HorseDetailModel()
        emptyModel.load(id: fixture.horse.persistentModelID, in: fixture.context)
        #expect(emptyModel.historyLoadState == .loaded)
        #expect(emptyModel.history.isEmpty)

        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: [fixture.horse],
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: fixture.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        try DomainGraphValidator.save(fixture.context)

        visit.barn = nil
        let entries = try HorseDetailModel.loadHistory(
            horseID: fixture.horse.persistentModelID,
            in: fixture.context
        )

        #expect(entries.count == 1)
        #expect(entries[0].serviceLocationName == "North Field")
        #expect(entries[0].visitID == visit.persistentModelID)
    }

    @Test
    func historyReloadsCompletedVisitsWrittenByASeparateContext() throws {
        let fixture = try makeHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: [fixture.horse],
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)

        let staleContext = ModelContext(fixture.container)
        let staleAppointment = try #require(
            staleContext.model(for: appointment.persistentModelID) as? Appointment
        )
        #expect(staleAppointment.visit == nil)

        let visitID = try VisitStartUseCase.start(
            appointmentID: appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 100),
            in: fixture.container
        )
        let saveContext = ModelContext(fixture.container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visitID, in: saveContext)
        draft.horses[0].outcome = .serviced
        _ = try VisitSaveUseCase.complete(
            draft: draft,
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            in: saveContext
        )

        let model = HorseDetailModel()
        model.load(id: fixture.horse.persistentModelID, in: staleContext)

        #expect(model.historyLoadState == .loaded)
        #expect(model.history.count == 1)
        #expect(model.history[0].visitID == visitID)
    }

    @Test
    func missingVisitHorseRelationshipFailsClosedInsteadOfShowingAnEmptyHistory() throws {
        let fixture = try makeHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: [fixture.horse],
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: fixture.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.horse = nil

        #expect(throws: HorseHistoryLoadError.invalidHistory) {
            try HorseDetailModel.loadHistory(
                horseID: fixture.horse.persistentModelID,
                in: fixture.context
            )
        }
    }

    @Test
    func missingVisitRelationshipFailsClosedInsteadOfShowingAnEmptyHistory() throws {
        let fixture = try makeHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: [fixture.horse],
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: fixture.context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.visit = nil

        #expect(throws: HorseHistoryLoadError.invalidHistory) {
            try HorseDetailModel.loadHistory(
                horseID: fixture.horse.persistentModelID,
                in: fixture.context
            )
        }
    }

    private func makeHorseFixture() throws -> (
        container: ModelContainer,
        context: ModelContext,
        barn: Barn,
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
        try DomainGraphValidator.save(context)
        return (container, context, barn, horse)
    }

    private func makeIdentifiers(count: Int) throws -> [PersistentIdentifier] {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let clients = (0..<count).map { Client(name: "Client \($0)") }
        for client in clients {
            context.insert(client)
        }
        try context.save()
        return clients.map(\.persistentModelID)
    }

    private func identifierKey(_ identifier: PersistentIdentifier) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(identifier)
    }
}

private enum HorseHistoryTestFailure: Error {
    case unavailable
}
