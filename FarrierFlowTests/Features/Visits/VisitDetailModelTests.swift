import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Visit detail")
@MainActor
struct VisitDetailModelTests {
    @Test
    func completedVisitLoadsImmutableSnapshotsAndAllHorseResults() throws {
        let graph = try makeCompletedGraph()
        let model = VisitDetailModel(visitID: graph.visitID, in: graph.container)

        model.load()

        let detail = try #require(model.detail)
        #expect(model.loadState == .loaded)
        #expect(detail.startedAt == Date(timeIntervalSinceReferenceDate: 100))
        #expect(detail.completedAt == Date(timeIntervalSinceReferenceDate: 200))
        #expect(detail.serviceLocationNameSnapshot == "North Field")
        #expect(detail.serviceLocationAddressSnapshot == "25 Stable Lane")
        #expect(detail.barnID == graph.barnID)
        #expect(detail.horses.count == 2)
        #expect(detail.horses.contains { $0.workNotes == "Front shoes" })
        let milo = try #require(detail.horses.first { $0.horseName == "Milo" })
        #expect(milo.workItems.map(\.serviceNameSnapshot) == ["Basic Trim"])
        #expect(milo.subtotal == .available(5_000))
        #expect(detail.total == .available(5_000))
    }

    @Test
    func completedDetailUsesWorkItemSnapshotsAndKeepsMissingServiceNavigationSafe() throws {
        let graph = try makeCompletedGraph()
        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        let visitHorse = try #require(visit.visitHorses.first { $0.horse?.name == "Milo" })
        let workItem = try #require(visitHorse.workItems.first)
        let service = try #require(workItem.service)

        service.name = "Renamed Trim"
        service.defaultAmountMinorUnits = 9_999
        service.isArchived = true
        try context.save()

        let archivedDetail = try VisitDetailModel.loadDetail(
            visitID: graph.visitID,
            in: context,
            locale: Locale(identifier: "en_US")
        )
        let archivedWorkItem = try #require(
            archivedDetail.horses.first { $0.horseName == "Milo" }?.workItems.first
        )
        #expect(archivedWorkItem.serviceNameSnapshot == "Basic Trim")
        #expect(archivedWorkItem.amountMinorUnits == 5_000)
        #expect(archivedWorkItem.serviceID == service.persistentModelID)
        #expect(archivedWorkItem.serviceIsArchived == true)

        workItem.service = nil
        try context.save()

        let missingServiceDetail = try VisitDetailModel.loadDetail(
            visitID: graph.visitID,
            in: context,
            locale: Locale(identifier: "en_US")
        )
        let missingServiceWorkItem = try #require(
            missingServiceDetail.horses.first { $0.horseName == "Milo" }?.workItems.first
        )
        #expect(missingServiceWorkItem.serviceNameSnapshot == "Basic Trim")
        #expect(missingServiceWorkItem.amountMinorUnits == 5_000)
        #expect(missingServiceWorkItem.serviceID == nil)
        #expect(missingServiceWorkItem.serviceIsArchived == nil)
    }

    @Test
    func legacyServicedHorseWithoutRecordedServicesKeepsTotalsUnavailable() throws {
        let graph = try makeLegacyCompletedGraph()

        let detail = try VisitDetailModel.loadDetail(
            visitID: graph.visitID,
            in: graph.container.mainContext,
            locale: Locale(identifier: "en_US")
        )

        let horse = try #require(detail.horses.first)
        #expect(horse.outcome == .serviced)
        #expect(horse.workItems.isEmpty)
        #expect(horse.subtotal == .unavailable)
        #expect(detail.total == .unavailable)
    }

    @Test
    func missingBarnStillLoadsSnapshotWithoutNavigation() throws {
        let graph = try makeCompletedGraph()
        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        visit.barn = nil
        try context.save()

        let model = VisitDetailModel(visitID: graph.visitID, in: graph.container)
        model.load()

        let detail = try #require(model.detail)
        #expect(model.loadState == .loaded)
        #expect(detail.serviceLocationNameSnapshot == "North Field")
        #expect(detail.serviceLocationAddressSnapshot == "25 Stable Lane")
        #expect(detail.barnID == nil)
    }

    @Test
    func invalidVisitHorseAndUnknownOutcomeShowUnavailableStateAndRetry() throws {
        let graph = try makeCompletedGraph()
        var attempt = 0
        let model = VisitDetailModel(
            visitID: graph.visitID,
            in: graph.container,
            loading: { visitID, context, locale in
                attempt += 1
                if attempt == 1 {
                    throw VisitDetailTestFailure.unavailable
                }
                return try VisitDetailModel.loadDetail(
                    visitID: visitID,
                    in: context,
                    locale: locale
                )
            }
        )

        model.load()
        #expect(model.loadState == .failed)
        #expect(model.detail == nil)

        model.retry()
        #expect(model.loadState == .loaded)

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = "invalid"
        try context.save()
        let invalidModel = VisitDetailModel(visitID: graph.visitID, in: graph.container)
        invalidModel.load()
        #expect(invalidModel.loadState == .failed)
        #expect(invalidModel.detail == nil)

        let missingRelationship = try makeCompletedGraph()
        let relationshipContext = ModelContext(missingRelationship.container)
        let invalidVisit = try #require(
            relationshipContext.model(for: missingRelationship.visitID) as? Visit
        )
        let invalidVisitHorse = try #require(invalidVisit.visitHorses.first)
        invalidVisitHorse.horse = nil
        try relationshipContext.save()
        let missingRelationshipModel = VisitDetailModel(
            visitID: missingRelationship.visitID,
            in: missingRelationship.container
        )
        missingRelationshipModel.load()
        #expect(missingRelationshipModel.loadState == .failed)
        #expect(missingRelationshipModel.detail == nil)
    }

    @Test
    func inProgressDetailResumesAndCompletedDetailEditsWithoutDeleteRoute() throws {
        let inProgress = try makeInProgressGraph()
        let inProgressModel = VisitDetailModel(
            visitID: inProgress.visitID,
            in: inProgress.container
        )
        inProgressModel.load()
        #expect(inProgressModel.editorMode == .inProgress)

        let completed = try makeCompletedGraph()
        let completedModel = VisitDetailModel(
            visitID: completed.visitID,
            in: completed.container
        )
        completedModel.load()
        #expect(completedModel.editorMode == .correction)
    }

    @Test
    func completedDetailRejectsCorruptedVisitInvariantsExceptMissingBarnFallback() throws {
        try assertUnavailableAfterDirectSave { visit, _ in
            visit.visitHorses[0].outcomeRawValue = VisitOutcome.pending.rawValue
        }
        try assertUnavailableAfterDirectSave { visit, _ in
            for visitHorse in visit.visitHorses {
                visitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue
            }
        }
        try assertUnavailableAfterDirectSave { visit, _ in
            let firstHorse = try #require(visit.visitHorses.first?.horse)
            let secondMembership = try #require(visit.visitHorses.dropFirst().first)
            secondMembership.horse = firstHorse
        }
        try assertUnavailableAfterDirectSave { visit, _ in
            visit.serviceLocationNameSnapshot = "   "
        }
        try assertUnavailableAfterDirectSave { visit, _ in
            let horse = try #require(visit.visitHorses.first)
            horse.outcomeRawValue = VisitOutcome.notServiced.rawValue
            horse.workNotes = "Must be rejected"
        }
        try assertUnavailableAfterDirectSave { visit, _ in
            visit.completedAt = Date(timeIntervalSinceReferenceDate: 99)
        }
        try assertUnavailableAfterDirectSave { visit, _ in
            visit.appointment = nil
        }
    }

    @Test
    func completedDetailRemainsReadableAfterHorseRelocation() throws {
        let graph = try makeCompletedGraph()
        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        let horse = try #require(visit.visitHorses.first?.horse)
        let newBarn = Barn(name: "South Field")
        context.insert(newBarn)
        horse.currentBarn = newBarn
        newBarn.horses.append(horse)
        try context.save()

        let model = VisitDetailModel(visitID: graph.visitID, in: graph.container)
        model.load()

        #expect(model.loadState == .loaded)
        #expect(model.detail?.serviceLocationNameSnapshot == "North Field")
    }

    @Test
    func horseRowsUseLocalizedNameAndIdentifierOrderAcrossStoreReopening() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Visit-Detail-Order-"
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
            let horses = [
                Horse(name: "Same", client: client, currentBarn: barn),
                Horse(name: "Alpha", client: client, currentBarn: barn),
                Horse(name: "Same", client: client, currentBarn: barn),
            ]
            for horse in horses {
                context.insert(horse)
            }
            client.horses.append(contentsOf: horses)
            barn.horses.append(contentsOf: horses)
            let appointment = ModelFixtures.makeAppointment(
                barn: barn,
                horses: horses,
                in: context
            )
            try DomainGraphValidator.save(context)
            _ = try VisitStartUseCase.start(
                appointmentID: appointment.persistentModelID,
                now: Date(timeIntervalSinceReferenceDate: 100),
                in: container
            )

            let detailContext = ModelContext(container)
            let visit = try #require(
                detailContext.fetch(FetchDescriptor<Visit>()).first
            )
            let storedVisitID = visit.persistentModelID
            let alphaID = try #require(
                visit.visitHorses.first { $0.horse?.name == "Alpha" }?
                    .persistentModelID
            )
            let sameIDs = visit.visitHorses
                .filter { $0.horse?.name == "Same" }
                .map(\.persistentModelID)
                .sorted()
            expectedIDs = [alphaID] + sameIDs
            visit.visitHorses.sort { $0.persistentModelID > $1.persistentModelID }
            try detailContext.save()

            let detail = try VisitDetailModel.loadDetail(
                visitID: storedVisitID,
                in: detailContext,
                locale: Locale(identifier: "en_US")
            )
            firstOrder = detail.horses.map(\.id)
            expectedIdentifierKeys = try expectedIDs.map(identifierKey)
            #expect(detail.horses.map(\.horseName) == ["Alpha", "Same", "Same"])
            #expect(firstOrder == expectedIDs)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let storedVisitID = try #require(
                context.fetch(FetchDescriptor<Visit>()).first
            ).persistentModelID
            let reopened = try VisitDetailModel.loadDetail(
                visitID: storedVisitID,
                in: context,
                locale: Locale(identifier: "en_US")
            )
            let reopenedIdentifierKeys = try reopened.horses.map {
                try identifierKey($0.id)
            }

            #expect(reopenedIdentifierKeys == expectedIdentifierKeys)
        }
    }

    private func makeInProgressGraph() throws -> VisitDetailGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        return try makeGraph(container: container, completedAt: nil)
    }

    private func makeCompletedGraph() throws -> VisitDetailGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        return try makeGraph(
            container: container,
            completedAt: Date(timeIntervalSinceReferenceDate: 200)
        )
    }

    private func makeGraph(
        container: ModelContainer,
        completedAt: Date?
    ) throws -> VisitDetailGraph {
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field", address: "25 Stable Lane")
        context.insert(client)
        context.insert(barn)
        let firstHorse = Horse(name: "Milo", client: client, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: client, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        client.horses.append(contentsOf: [firstHorse, secondHorse])
        barn.horses.append(contentsOf: [firstHorse, secondHorse])
        let defaultService = ModelFixtures.makeService(
            name: "Basic Trim",
            defaultAmountMinorUnits: 5_000,
            in: context
        )
        firstHorse.defaultService = defaultService
        defaultService.horsesUsingAsDefault.append(firstHorse)
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [firstHorse, secondHorse],
            in: context
        )
        try DomainGraphValidator.save(context)
        let visitID = try VisitStartUseCase.start(
            appointmentID: appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 100),
            in: container
        )
        if let completedAt {
            let actionContext = ModelContext(container)
            var draft = try VisitSaveUseCase.loadDraft(visitID: visitID, in: actionContext)
            let miloIndex = try horseIndex(named: "Milo", in: draft)
            let scoutIndex = try horseIndex(named: "Scout", in: draft)
            draft.horses[miloIndex].outcome = .serviced
            draft.horses[miloIndex].workNotes = "Front shoes"
            draft.horses[scoutIndex].outcome = .notServiced
            _ = try VisitSaveUseCase.complete(
                draft: draft,
                completedAt: completedAt,
                in: actionContext
            )
        }
        return VisitDetailGraph(container: container, visitID: visitID, barnID: barn.persistentModelID)
    }

    private func makeLegacyCompletedGraph() throws -> VisitDetailGraph {
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
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            workItemPolicyVersion: 0,
            appointment: appointment,
            in: context
        )
        visit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
        try DomainGraphValidator.save(context)
        return VisitDetailGraph(
            container: container,
            visitID: visit.persistentModelID,
            barnID: barn.persistentModelID
        )
    }

    private func horseIndex(named horseName: String, in draft: VisitDraft) throws -> Int {
        try #require(draft.horses.firstIndex(where: { $0.horseName == horseName }))
    }

    private func identifierKey(_ identifier: PersistentIdentifier) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(identifier)
    }

    private func assertUnavailableAfterDirectSave(
        mutation: (Visit, ModelContext) throws -> Void
    ) throws {
        let graph = try makeCompletedGraph()
        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        try mutation(visit, context)
        try context.save()

        let model = VisitDetailModel(visitID: graph.visitID, in: graph.container)
        model.load()

        #expect(model.loadState == .failed)
        #expect(model.detail == nil)
    }
}

private struct VisitDetailGraph {
    let container: ModelContainer
    let visitID: PersistentIdentifier
    let barnID: PersistentIdentifier
}

private enum VisitDetailTestFailure: Error {
    case unavailable
}
