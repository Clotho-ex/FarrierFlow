import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Service catalog lifecycle")
@MainActor
struct ServiceDetailModelTests {
    @Test
    func listLoadsActiveAndArchivedServicesInDeterministicSections() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeService(name: "Archived", isArchived: true, in: context)
        _ = ModelFixtures.makeService(name: "Z Balance", in: context)
        _ = ModelFixtures.makeService(name: "A Trim", in: context)
        try context.save()

        let model = ServiceListModel()
        model.load(in: context, locale: Locale(identifier: "en_US"))

        #expect(model.loadState == .loaded)
        #expect(model.activeServices.map(\.name) == ["A Trim", "Z Balance"])
        #expect(model.archivedServices.map(\.name) == ["Archived"])
    }

    @Test
    func listReportsFailureAndRetainsNoFabricatedServices() throws {
        let model = ServiceListModel(serviceFetcher: { _ in throw TestLoadError.failed })
        let container = try ModelContainerFactory.inMemoryTest()

        model.load(in: container.mainContext)

        #expect(model.loadState == .failed)
        #expect(model.activeServices.isEmpty)
        #expect(model.archivedServices.isEmpty)
    }

    @Test
    func archiveIsBlockedByHorseDefaultAndDoesNotClearIt() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        let service = ModelFixtures.makeService(in: context)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn, defaultService: service)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)

        let model = ServiceDetailModel()
        model.load(id: service.persistentModelID, in: context)

        #expect(!model.archive(in: context))
        #expect(!service.isArchived)
        #expect(horse.defaultService === service)
        #expect(model.delete(in: context))
        #expect(horse.defaultService == nil)
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 0)
    }

    @Test
    func archiveAllowsRecordedWorkAndReactivateRestoresTheService() throws {
        let (container, service) = try serviceWithRecordedWork()
        let context = container.mainContext
        let model = ServiceDetailModel()
        model.load(id: service.persistentModelID, in: context)

        #expect(model.archive(in: context))
        #expect(service.isArchived)
        #expect(model.reactivate(in: context))
        #expect(!service.isArchived)
    }

    @Test
    func deletingServicesPreservesRecordedWork() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let unreferenced = ModelFixtures.makeService(in: context)
        try context.save()

        let model = ServiceDetailModel()
        model.load(id: unreferenced.persistentModelID, in: context)
        #expect(model.delete(in: context))
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 0)

        let (referencedContainer, referenced) = try serviceWithRecordedWork()
        let referencedContext = referencedContainer.mainContext
        let referencedModel = ServiceDetailModel()
        referencedModel.load(id: referenced.persistentModelID, in: referencedContext)
        #expect(referencedModel.delete(in: referencedContext))
        #expect(referencedModel.alert == nil)
        #expect(try referencedContext.fetchCount(FetchDescriptor<Service>()) == 0)
        #expect(try referencedContext.fetchCount(FetchDescriptor<WorkItem>()) == 1)
        try DomainGraphValidator.validateAll(in: referencedContext)
    }

    @Test(arguments: [false, true])
    func deletedServicesKeepVisitWorkEditable(completed: Bool) throws {
        let (container, service) = try serviceWithRecordedWork()
        let context = container.mainContext
        let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)
        if !completed { visit.completedAt = nil }
        let member = try #require(visit.visitHorses.first)
        let otherService = ModelFixtures.makeService(name: "Brushing", in: context)
        _ = ModelFixtures.makeWorkItem(service: otherService, visitHorse: member, in: context)
        try DomainGraphValidator.save(context)
        try RecordDeletionRules.delete(service, in: context)
        try RecordDeletionRules.delete(otherService, in: context)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visit.persistentModelID, in: context)
        #expect(draft.horses[0].workItems.count == 2)
        #expect(draft.horses[0].workItems.allSatisfy { $0.serviceID == nil })
        #expect(VisitRules.batchSourceViolation(for: draft.horses[0]) == .sourceContainsDeletedService)
        draft.horses[0].workItems[0].amountMinorUnits = 8_000
        let saved = try completed
            ? VisitSaveUseCase.saveCorrection(draft: draft, in: context)
            : VisitSaveUseCase.saveProgress(draft: draft, in: context)
        #expect(saved.horses[0].workItems[0].amountMinorUnits == 8_000)
        #expect(saved.horses[0].workItems.count == 2)
        try DomainGraphValidator.validateAll(in: context)
    }

    @Test
    func savingNewWorkWithoutACatalogServiceIsRejected() throws {
        let (container, _) = try serviceWithRecordedWork()
        let context = container.mainContext
        let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visit.persistentModelID, in: context)
        draft.horses[0].workItems.append(WorkItemDraft(
            serviceID: nil, serviceNameSnapshot: "Deleted Service", amountMinorUnits: 5_000
        ))
        #expect(throws: DomainGraphViolation.workItemMissingService) {
            _ = try VisitSaveUseCase.saveCorrection(draft: draft, in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 1)
        try DomainGraphValidator.validateAll(in: context)
    }

    private func serviceWithRecordedWork() throws -> (ModelContainer, Service) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: [horse], in: context)
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: context)
        _ = ModelFixtures.makeWorkItem(service: service, visitHorse: visitHorse, in: context)
        try DomainGraphValidator.save(context)
        return (container, service)
    }
}

private enum TestLoadError: Error {
    case failed
}
