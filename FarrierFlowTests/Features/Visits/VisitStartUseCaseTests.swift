import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Visit start")
@MainActor
struct VisitStartUseCaseTests {
    @Test
    func startingVisitCopiesAppointmentMembershipAndLocationSnapshots() throws {
        let graph = try makeTwoHorseGraph()
        let startedAt = Date(timeIntervalSinceReferenceDate: 123_456)

        let visitID = try VisitStartUseCase.start(
            appointmentID: graph.appointment.persistentModelID,
            now: startedAt,
            in: graph.container
        )

        let verificationContext = ModelContext(graph.container)
        let appointment = try #require(
            verificationContext.model(for: graph.appointment.persistentModelID) as? Appointment
        )
        let barn = try #require(
            verificationContext.model(for: graph.barn.persistentModelID) as? Barn
        )
        let visit = try #require(verificationContext.model(for: visitID) as? Visit)
        let appointmentHorseIDs = Set(
            appointment.appointmentHorses.compactMap(\.horse?.persistentModelID)
        )
        let visitHorseIDs = Set(visit.visitHorses.compactMap(\.horse?.persistentModelID))

        #expect(try verificationContext.fetchCount(FetchDescriptor<Visit>()) == 1)
        #expect(try verificationContext.fetchCount(FetchDescriptor<VisitHorse>()) == 2)
        #expect(visitHorseIDs == appointmentHorseIDs)
        #expect(visit.visitHorses.allSatisfy { $0.outcomeRawValue == VisitOutcome.pending.rawValue })
        #expect(visit.startedAt == startedAt)
        #expect(visit.completedAt == nil)
        #expect(visit.workItemPolicyVersion == 1)
        #expect(visit.serviceLocationNameSnapshot == "North Field")
        #expect(visit.serviceLocationAddressSnapshot == "South gate")
        #expect(visit.appointment === appointment)
        #expect(appointment.visit === visit)
        #expect(visit.barn === barn)
        #expect(barn.visits.contains { $0 === visit })
        #expect(visit.visitHorses.allSatisfy { membership in
            membership.visit === visit
                && membership.horse?.visitHorses.contains { $0 === membership } == true
        })
        #expect(visit.visitHorses.allSatisfy { $0.workItems.isEmpty })
    }

    @Test
    func startingVisitCopiesEachActiveHorseDefaultServiceIntoExactlyOneWorkItem() throws {
        let graph = try makeTwoHorseGraph()
        let defaultService = ModelFixtures.makeService(
            name: "Full Set",
            defaultAmountMinorUnits: 12_500,
            in: graph.context
        )
        graph.horses[0].defaultService = defaultService
        defaultService.horsesUsingAsDefault.append(graph.horses[0])
        try DomainGraphValidator.save(graph.context)

        let visitID = try VisitStartUseCase.start(
            appointmentID: graph.appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 123_456),
            in: graph.container
        )

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: visitID) as? Visit)
        let service = try #require(
            context.model(for: defaultService.persistentModelID) as? Service
        )
        let defaultedVisitHorse = try #require(
            visit.visitHorses.first { $0.horse?.persistentModelID == graph.horses[0].persistentModelID }
        )

        #expect(visit.workItemPolicyVersion == 1)
        #expect(defaultedVisitHorse.workItems.count == 1)
        let workItem = try #require(defaultedVisitHorse.workItems.first)
        #expect(workItem.service?.persistentModelID == service.persistentModelID)
        #expect(workItem.serviceNameSnapshot == "Full Set")
        #expect(workItem.amountMinorUnits == 12_500)
        #expect(workItem.currencyCode == "USD")
        #expect(service.workItems.contains { $0.persistentModelID == workItem.persistentModelID })
        #expect(workItem.visitHorse === defaultedVisitHorse)
        #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 1)
    }

    @Test
    func archivedHorseDefaultBlocksStartWithoutCreatingAnyVisitRecords() throws {
        let graph = try makeTwoHorseGraph()
        let service = ModelFixtures.makeService(
            name: "Full Set",
            defaultAmountMinorUnits: 12_500,
            isArchived: true,
            in: graph.context
        )
        graph.horses[0].defaultService = service
        service.horsesUsingAsDefault.append(graph.horses[0])
        try graph.context.save()

        #expect(throws: DomainGraphViolation.horseDefaultServiceArchived) {
            try VisitStartUseCase.start(
                appointmentID: graph.appointment.persistentModelID,
                now: Date(timeIntervalSinceReferenceDate: 123_456),
                in: graph.container
            )
        }

        #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<VisitHorse>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
        #expect(graph.appointment.visit == nil)
    }

    @Test(arguments: VisitStartInvalidGraph.allCases)
    fileprivate func startRejectsInvalidSourceGraphWithoutCreatingVisit(
        invalidGraph: VisitStartInvalidGraph
    ) throws {
        let graph = try makeTwoHorseGraph()
        try invalidGraph.apply(to: graph)

        #expect(throws: (any Error).self) {
            try VisitStartUseCase.start(
                appointmentID: graph.appointment.persistentModelID,
                now: Date(timeIntervalSinceReferenceDate: 100),
                in: graph.container
            )
        }

        #expect(
            try graph.context.fetchCount(FetchDescriptor<Visit>())
                == invalidGraph.expectedVisitCount
        )
        #expect(
            try graph.context.fetchCount(FetchDescriptor<VisitHorse>())
                == invalidGraph.expectedVisitHorseCount
        )
    }

    @Test
    func startRejectsAppointmentWithoutMembershipsBeforeVisitMutation() throws {
        let graph = try makeTwoHorseGraph()
        let actionContext = ModelContext(graph.container)
        let memberships = try actionContext.fetch(FetchDescriptor<AppointmentHorse>())
        for membership in memberships {
            actionContext.delete(membership)
        }

        #expect(throws: DomainGraphViolation.appointmentHasNoValidHorse) {
            try VisitStartUseCase.start(
                appointmentID: graph.appointment.persistentModelID,
                now: Date(timeIntervalSinceReferenceDate: 100),
                in: graph.container,
                actionContext: actionContext,
                saving: { _ in }
            )
        }

        #expect(try graph.context.fetchCount(FetchDescriptor<Visit>()) == 0)
        #expect(try graph.context.fetchCount(FetchDescriptor<VisitHorse>()) == 0)
    }

    @Test
    func failedSaveRollsBackVisitGraphAndCannotLeakIntoLaterSaveOrReopen() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Failed-Visit-Start-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let graph = try makeTwoHorseGraph(in: context, container: container)
            let service = ModelFixtures.makeService(in: context)
            graph.horses[0].defaultService = service
            service.horsesUsingAsDefault.append(graph.horses[0])
            try DomainGraphValidator.save(context)

            #expect(throws: ForcedSaveFailure.unavailable) {
                try VisitStartUseCase.start(
                    appointmentID: graph.appointment.persistentModelID,
                    now: Date(timeIntervalSinceReferenceDate: 100),
                    in: container,
                    saving: { _ in throw ForcedSaveFailure.unavailable }
                )
            }

            #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<VisitHorse>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
            #expect(graph.appointment.visit == nil)
            #expect(graph.barn.visits.isEmpty)
            #expect(graph.horses.allSatisfy { $0.visitHorses.isEmpty })
            #expect(graph.appointment.appointmentHorses.count == 2)

            graph.clients[0].notes = "An unrelated later save"
            try DomainGraphValidator.save(context)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)

            #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<VisitHorse>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<WorkItem>()) == 0)
            let appointment = try #require(
                context.fetch(FetchDescriptor<Appointment>()).first
            )
            #expect(appointment.visit == nil)
            #expect(appointment.appointmentHorses.count == 2)
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    private func makeTwoHorseGraph() throws -> VisitStartGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        return try makeTwoHorseGraph(in: container.mainContext, container: container)
    }

    private func makeTwoHorseGraph(
        in context: ModelContext,
        container: ModelContainer
    ) throws -> VisitStartGraph {
        let firstClient = Client(name: "Alex")
        let secondClient = Client(name: "Jordan")
        let barn = Barn(name: "  North Field  ", address: "  South gate  ")
        context.insert(firstClient)
        context.insert(secondClient)
        context.insert(barn)

        let firstHorse = Horse(name: "Milo", client: firstClient, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: secondClient, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        firstClient.horses.append(firstHorse)
        secondClient.horses.append(secondHorse)
        barn.horses.append(contentsOf: [firstHorse, secondHorse])

        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [firstHorse, secondHorse],
            in: context
        )
        try DomainGraphValidator.save(context)

        return VisitStartGraph(
            container: container,
            context: context,
            clients: [firstClient, secondClient],
            barn: barn,
            horses: [firstHorse, secondHorse],
            appointment: appointment
        )
    }
}

fileprivate enum VisitStartInvalidGraph: CaseIterable {
    case noBarn
    case missingHorse
    case duplicateHorse
    case horseOutsideBarn
    case missingClient
    case missingCurrentBarn
    case existingVisit
    case blankBarnName

    var expectedVisitCount: Int {
        self == .existingVisit ? 1 : 0
    }

    var expectedVisitHorseCount: Int {
        self == .existingVisit ? 2 : 0
    }

    @MainActor
    func apply(to graph: VisitStartGraph) throws {
        switch self {
        case .noBarn:
            graph.appointment.barn = nil
        case .missingHorse:
            let membership = try #require(graph.appointment.appointmentHorses.first)
            membership.horse = nil
        case .duplicateHorse:
            let duplicate = AppointmentHorse(
                appointment: graph.appointment,
                horse: graph.horses[0]
            )
            graph.context.insert(duplicate)
            graph.appointment.appointmentHorses.append(duplicate)
            graph.horses[0].appointmentHorses.append(duplicate)
        case .horseOutsideBarn:
            let otherBarn = Barn(name: "Other Field")
            graph.context.insert(otherBarn)
            graph.horses[0].currentBarn = otherBarn
            otherBarn.horses.append(graph.horses[0])
        case .missingClient:
            graph.horses[0].client = nil
        case .missingCurrentBarn:
            graph.horses[0].currentBarn = nil
        case .existingVisit:
            _ = ModelFixtures.makeVisit(appointment: graph.appointment, in: graph.context)
        case .blankBarnName:
            graph.barn.name = " \n "
        }

        try graph.context.save()
    }
}

private struct VisitStartGraph {
    let container: ModelContainer
    let context: ModelContext
    let clients: [Client]
    let barn: Barn
    let horses: [Horse]
    let appointment: Appointment
}

private enum ForcedSaveFailure: Error, Equatable {
    case unavailable
}
