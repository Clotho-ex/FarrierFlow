import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("WorkItem domain validation", .serialized)
@MainActor
struct WorkItemDomainValidationTests {
    @Test
    func completedServicedHorseRequiresRecordedWorkItem() throws {
        let graph = try makeVisitGraph(completed: true)

        #expect(throws: DomainGraphViolation.completedServicedVisitHorseHasNoWorkItems) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func completedServicedHorseWithValidWorkItemPasses() throws {
        let graph = try makeVisitGraph(completed: true)
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: graph.visitHorse,
            in: graph.context
        )

        try DomainGraphValidator.validateAll(in: graph.context)
    }

    @Test
    func rejectsWorkItemForNotServicedHorse() throws {
        let graph = try makeVisitGraph(completed: false)
        graph.visitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: graph.visitHorse,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.notServicedVisitHorseHasWorkItems) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func rejectsDuplicateServiceForOneVisitHorse() throws {
        let graph = try makeVisitGraph(completed: false)
        let service = ModelFixtures.makeService(in: graph.context)
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: graph.visitHorse,
            in: graph.context
        )
        _ = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: graph.visitHorse,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.duplicateWorkItemService) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test(arguments: [
        ("name", DomainGraphViolation.serviceNameNotNormalized),
        ("amount", DomainGraphViolation.serviceAmountNegative),
        ("currency", DomainGraphViolation.serviceCurrencyInvalid),
    ])
    func rejectsInvalidServicePersistence(
        mutation: String,
        expectedViolation: DomainGraphViolation
    ) throws {
        let graph = try makeVisitGraph(completed: false)
        let service = ModelFixtures.makeService(in: graph.context)

        switch mutation {
        case "name":
            service.name = "  "
        case "amount":
            service.defaultAmountMinorUnits = -1
        case "currency":
            service.currencyCode = "EUR"
        default:
            Issue.record("Unexpected Service mutation")
        }

        #expect(throws: expectedViolation) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func rejectsArchivedHorseDefaultService() throws {
        let graph = try makeVisitGraph(completed: false)
        let service = ModelFixtures.makeService(isArchived: true, in: graph.context)
        graph.horse.defaultService = service
        service.horsesUsingAsDefault.append(graph.horse)

        #expect(throws: DomainGraphViolation.horseDefaultServiceArchived) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test(arguments: [
        ("snapshot", DomainGraphViolation.workItemServiceNameSnapshotNotNormalized),
        ("amount", DomainGraphViolation.workItemAmountNegative),
        ("currency", DomainGraphViolation.workItemCurrencyInvalid),
        ("service", DomainGraphViolation.workItemMissingService),
        ("owner", DomainGraphViolation.workItemMissingVisitHorse),
    ])
    func rejectsInvalidWorkItemPersistence(
        mutation: String,
        expectedViolation: DomainGraphViolation
    ) throws {
        let graph = try makeVisitGraph(completed: false)
        let service = ModelFixtures.makeService(in: graph.context)
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: graph.visitHorse,
            in: graph.context
        )

        switch mutation {
        case "snapshot":
            workItem.serviceNameSnapshot = "  "
        case "amount":
            workItem.amountMinorUnits = -1
        case "currency":
            workItem.currencyCode = "EUR"
        case "service":
            workItem.service = nil
        case "owner":
            workItem.visitHorse = nil
        default:
            Issue.record("Unexpected WorkItem mutation")
        }

        #expect(throws: expectedViolation) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    @Test
    func rejectsOverflowingRecordedVisitTotal() throws {
        let graph = try makeVisitGraph(completed: false)
        let firstService = ModelFixtures.makeService(
            name: "First",
            defaultAmountMinorUnits: Int64.max,
            in: graph.context
        )
        let secondService = ModelFixtures.makeService(
            name: "Second",
            defaultAmountMinorUnits: 1,
            in: graph.context
        )
        _ = ModelFixtures.makeWorkItem(
            service: firstService,
            visitHorse: graph.visitHorse,
            in: graph.context
        )
        _ = ModelFixtures.makeWorkItem(
            service: secondService,
            visitHorse: graph.visitHorse,
            in: graph.context
        )

        #expect(throws: DomainGraphViolation.workItemTotalOverflow) {
            try DomainGraphValidator.validateAll(in: graph.context)
        }
    }

    private func makeVisitGraph(completed: Bool) throws -> (
        container: ModelContainer,
        context: ModelContext,
        horse: Horse,
        visitHorse: VisitHorse
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
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: completed ? Date(timeIntervalSinceReferenceDate: 200) : nil,
            appointment: appointment,
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        return (container, context, horse, visitHorse)
    }
}
