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
            loading: { visitID, context in
                attempt += 1
                if attempt == 1 {
                    throw VisitDetailTestFailure.unavailable
                }
                return try VisitDetailModel.loadDetail(visitID: visitID, in: context)
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

    private func horseIndex(named horseName: String, in draft: VisitDraft) throws -> Int {
        try #require(draft.horses.firstIndex(where: { $0.horseName == horseName }))
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
