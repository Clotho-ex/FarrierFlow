import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Today contextual empty states")
@MainActor
struct TodayEmptyStateTests {
    @Test
    func readinessAdvancesAfterSavingEachRecord() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: .now, calendar: .current)
        #expect(model.emptyState == .addClient)

        let client = Client(name: "Alex")
        context.insert(client)
        try DomainGraphValidator.save(context)
        model.load(in: context, now: .now, calendar: .current)
        #expect(model.emptyState == .addHorse)
        #expect(model.primaryAction == .addHorse(client.persistentModelID))
        #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 0)

        let barn = Barn(name: "North Field")
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        model.load(in: context, now: .now, calendar: .current)
        #expect(model.emptyState == .noAppointments)
        #expect(model.primaryAction == .scheduleAppointment)
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 0)
        #expect(!context.hasChanges)
    }

    @Test
    func multipleClientsDoNotSilentlyChooseAnOwnerForTheFirstHorse() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        context.insert(Client(name: "Alex"))
        context.insert(Client(name: "Sam"))
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: .now, calendar: .current)
        #expect(model.primaryAction == .addHorse(nil))
    }

    @Test
    func clearDayShowsEarliestFutureScheduledWorkAcrossLocalDayBoundary() throws {
        let graph = try makeGraph()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)))
        let tomorrow = CalendarRules.dayInterval(containing: now, calendar: calendar).end
        for start in [tomorrow.addingTimeInterval(86_400), tomorrow] {
            _ = ModelFixtures.makeAppointment(startDate: start, barn: graph.barn, horses: [graph.horse], in: graph.container.mainContext)
        }
        try DomainGraphValidator.save(graph.container.mainContext)
        let model = TodayModel()
        model.load(in: graph.container.mainContext, now: now, calendar: calendar)
        #expect(model.emptyState == .noStops(nextAppointment: tomorrow))
        #expect(!model.dayIsComplete)
        #expect(model.remainingStops.isEmpty)

        model.load(in: graph.container.mainContext, now: tomorrow, calendar: calendar)
        #expect(model.emptyState == nil)
        #expect(model.featuredStop?.id.startDate == tomorrow)
    }

    @Test
    func completedDayPreservesStopsAndDoesNotTreatUnfinishedEarlierWorkAsDone() throws {
        let graph = try makeGraph()
        let context = graph.container.mainContext
        let now = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3_600)
        let appointment = ModelFixtures.makeAppointment(startDate: now.addingTimeInterval(-60), barn: graph.barn, horses: [graph.horse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: appointment.startDate, completedAt: now, appointment: appointment, in: context)
        visit.visitHorses[0].outcomeRawValue = VisitOutcome.notServiced.rawValue
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: now, calendar: .current)
        #expect(model.emptyState == .allDone)
        #expect(model.dayIsComplete)
        #expect(model.remainingStops.flatMap(\.appointments).map(\.id) == [appointment.persistentModelID])

        let unfinished = ModelFixtures.makeAppointment(startDate: appointment.startDate.addingTimeInterval(-60), barn: graph.barn, horses: [graph.horse], in: context)
        try DomainGraphValidator.save(context)
        model.load(in: context, now: now, calendar: .current)
        #expect(model.emptyState == nil)
        #expect(!model.dayIsComplete)
        #expect(model.featuredStop?.appointments.first?.id == unfinished.persistentModelID)
        #expect(unfinished.visit == nil)
        #expect(!context.hasChanges)
    }

    @Test
    func historicalAppointmentsAreNotMistakenForFirstUseOrCompletedToday() throws {
        let graph = try makeGraph()
        let now = Date.now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        _ = ModelFixtures.makeAppointment(startDate: yesterday, barn: graph.barn, horses: [graph.horse], in: graph.container.mainContext)
        try DomainGraphValidator.save(graph.container.mainContext)
        let model = TodayModel()
        model.load(in: graph.container.mainContext, now: now, calendar: .current)
        #expect(model.emptyState == .noStops(nextAppointment: nil))
        #expect(!model.dayIsComplete)
    }

    @Test
    func billingAttentionIsPreservedAfterTodaysStopsAreComplete() throws {
        let graph = try makeGraph()
        let context = graph.container.mainContext
        let now = Date.now
        let appointment = ModelFixtures.makeAppointment(startDate: now, barn: graph.barn, horses: [graph.horse], in: context)
        let visit = ModelFixtures.makeVisit(startedAt: now, completedAt: now, appointment: appointment, in: context)
        visit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
        _ = ModelFixtures.makeWorkItem(service: ModelFixtures.makeService(in: context), visitHorse: visit.visitHorses[0], in: context)
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: now, calendar: .current)
        #expect(model.dayIsComplete)
        #expect(model.emptyState == nil)
        guard case .createInvoice = model.primaryAction else {
            Issue.record("Completed work must retain its invoice action")
            return
        }
    }

    private func makeGraph() throws -> (container: ModelContainer, barn: Barn, horse: Horse) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        return (container, barn, horse)
    }
}
