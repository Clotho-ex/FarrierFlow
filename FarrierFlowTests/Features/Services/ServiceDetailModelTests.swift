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

        #expect(
            !model.archive(in: context, coordinator: PersistenceMutationCoordinator())
        )
        #expect(!service.isArchived)
        #expect(horse.defaultService === service)
        #expect(
            !model.delete(in: context, coordinator: PersistenceMutationCoordinator())
        )
        #expect(horse.defaultService === service)
    }

    @Test
    func archiveAllowsRecordedWorkAndReactivateRestoresTheService() throws {
        let (container, service) = try serviceWithRecordedWork()
        let context = container.mainContext
        let model = ServiceDetailModel()
        model.load(id: service.persistentModelID, in: context)

        #expect(model.archive(in: context, coordinator: PersistenceMutationCoordinator()))
        #expect(service.isArchived)
        #expect(
            model.reactivate(in: context, coordinator: PersistenceMutationCoordinator())
        )
        #expect(!service.isArchived)
    }

    @Test
    func deletesOnlyAnUnreferencedService() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let unreferenced = ModelFixtures.makeService(in: context)
        try context.save()

        let model = ServiceDetailModel()
        model.load(id: unreferenced.persistentModelID, in: context)
        #expect(model.delete(in: context, coordinator: PersistenceMutationCoordinator()))
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 0)

        let (referencedContainer, referenced) = try serviceWithRecordedWork()
        let referencedContext = referencedContainer.mainContext
        let referencedModel = ServiceDetailModel()
        referencedModel.load(id: referenced.persistentModelID, in: referencedContext)
        #expect(
            !referencedModel.delete(
                in: referencedContext,
                coordinator: PersistenceMutationCoordinator()
            )
        )
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
