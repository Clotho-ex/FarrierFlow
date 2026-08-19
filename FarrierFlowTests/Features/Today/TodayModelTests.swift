import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Today model")
@MainActor
struct TodayModelTests {
    @Test
    func initialLoadFailureUsesInlineRecoveryWithoutAlert() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let model = TodayModel()

        model.load(in: container.mainContext, now: .now, calendar: .current)

        #expect(model.loadState == .failed)
        #expect(model.alert == nil)
    }

    @Test
    func usesHalfOpenLocalDayAndPromotesOnlyTheFirstAppointment() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)
        ))
        let interval = try #require(calendar.dateInterval(of: .day, for: now))
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        for date in [
            interval.start.addingTimeInterval(-1),
            interval.start,
            interval.start.addingTimeInterval(3_600),
            interval.end,
        ] {
            _ = ModelFixtures.makeAppointment(
                startDate: date,
                barn: barn,
                horses: [horse],
                in: context
            )
        }
        try DomainGraphValidator.save(context)

        let model = TodayModel()
        model.load(in: context, now: now, calendar: calendar)

        guard case .openAppointment(let promoted) = model.primaryAction else {
            Issue.record("Expected the first current-day appointment")
            return
        }
        #expect(promoted.startDate == interval.start)
        #expect(model.remainingAppointments.map(\.startDate) == [
            interval.start.addingTimeInterval(3_600),
        ])
    }

    @Test
    func activeVisitOutranksAndRemovesItsAppointmentFromTheWorkline() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let activeAppointment = ModelFixtures.makeAppointment(
            startDate: now,
            barn: barn,
            horses: [horse],
            in: context
        )
        let laterAppointment = ModelFixtures.makeAppointment(
            startDate: now.addingTimeInterval(3_600),
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: now.addingTimeInterval(-600),
            appointment: activeAppointment,
            in: context
        )
        visit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
        _ = ModelFixtures.makeWorkItem(
            service: ModelFixtures.makeService(in: context),
            visitHorse: visit.visitHorses[0],
            in: context
        )
        try DomainGraphValidator.save(context)

        let model = TodayModel()
        model.load(in: context, now: now, calendar: .current)

        guard case .resumeVisit(let summary) = model.primaryAction else {
            Issue.record("Expected active Visit to rank first")
            return
        }
        #expect(summary.id == visit.persistentModelID)
        #expect(summary.resolvedHorseCount == 1)
        #expect(summary.totalHorseCount == 1)
        #expect(model.remainingAppointments.map(\.id) == [laterAppointment.persistentModelID])
    }

    @Test
    func remainingAppointmentsExposeTheirVisitState() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: .now)
        let firstStart = try #require(calendar.date(byAdding: .hour, value: 8, to: day))
        let secondStart = try #require(calendar.date(byAdding: .hour, value: 9, to: day))
        let completedStart = try #require(calendar.date(byAdding: .hour, value: 10, to: day))
        let now = try #require(calendar.date(byAdding: .hour, value: 12, to: day))
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let promotedAppointment = ModelFixtures.makeAppointment(
            startDate: firstStart,
            barn: barn,
            horses: [horse],
            in: context
        )
        _ = ModelFixtures.makeVisit(
            startedAt: firstStart,
            appointment: promotedAppointment,
            in: context
        )

        let activeAppointment = ModelFixtures.makeAppointment(
            startDate: secondStart,
            barn: barn,
            horses: [horse],
            in: context
        )
        _ = ModelFixtures.makeVisit(
            startedAt: secondStart,
            appointment: activeAppointment,
            in: context
        )

        let completedAppointment = ModelFixtures.makeAppointment(
            startDate: completedStart,
            barn: barn,
            horses: [horse],
            in: context
        )
        let completedVisit = ModelFixtures.makeVisit(
            startedAt: completedStart,
            completedAt: completedStart.addingTimeInterval(1_800),
            appointment: completedAppointment,
            in: context
        )
        completedVisit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
        _ = ModelFixtures.makeWorkItem(
            service: ModelFixtures.makeService(in: context),
            visitHorse: completedVisit.visitHorses[0],
            in: context
        )
        try DomainGraphValidator.save(context)

        let model = TodayModel()
        model.load(in: context, now: now, calendar: calendar)

        let stateByAppointment = Dictionary(
            uniqueKeysWithValues: model.remainingAppointments.map { ($0.id, $0.state) }
        )
        #expect(stateByAppointment[activeAppointment.persistentModelID] == .inProgress)
        #expect(stateByAppointment[completedAppointment.persistentModelID] == .completed)
    }

    @Test
    func firstClientOutranksContextualServiceAndLocationSetup() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        try DomainGraphValidator.save(context)
        let model = TodayModel()

        model.load(in: context, now: .now, calendar: .current)
        #expect(model.primaryAction == .addClient)

        context.insert(Client(name: "Alex"))
        try DomainGraphValidator.save(context)
        model.load(in: context, now: .now, calendar: .current)
        #expect(model.primaryAction == .scheduleAppointment)
    }

    @Test
    func invoiceCandidateCarriesTheExactOldestEligibleVisit() throws {
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
        let service = ModelFixtures.makeService(in: context)
        let firstStart = Date(timeIntervalSinceReferenceDate: 100)
        let secondStart = Date(timeIntervalSinceReferenceDate: 200)
        let firstVisit = ModelFixtures.makeVisit(
            startedAt: firstStart,
            completedAt: firstStart.addingTimeInterval(50),
            appointment: ModelFixtures.makeAppointment(
                startDate: firstStart,
                barn: barn,
                horses: [horse],
                in: context
            ),
            in: context
        )
        let secondVisit = ModelFixtures.makeVisit(
            startedAt: secondStart,
            completedAt: secondStart.addingTimeInterval(50),
            appointment: ModelFixtures.makeAppointment(
                startDate: secondStart,
                barn: barn,
                horses: [horse],
                in: context
            ),
            in: context
        )
        for visit in [firstVisit, secondVisit] {
            visit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
            _ = ModelFixtures.makeWorkItem(
                service: service,
                visitHorse: visit.visitHorses[0],
                in: context
            )
        }
        try DomainGraphValidator.save(context)
        let model = TodayModel()

        model.load(in: context, now: .now, calendar: .current)

        guard case .createInvoice(let candidate) = model.primaryAction else {
            Issue.record("Expected contextual Invoice creation")
            return
        }
        #expect(candidate.clientID == client.persistentModelID)
        #expect(candidate.visitID == firstVisit.persistentModelID)
        #expect(candidate.workDate == firstStart)
    }

    @Test
    func horseSummaryKeepsShortListsAndCondensesLongLists() {
        let shortSummary = TodayHorseSummary(horseNames: ["Iris", "Milo"])
        #expect(shortSummary.visibleHorseNames == ["Iris", "Milo"])
        #expect(shortSummary.remainingHorseCount == 0)

        let longSummary = TodayHorseSummary(
            horseNames: ["Iris", "Milo", "Nova", "Otis", "Poppy"]
        )
        #expect(longSummary.visibleHorseNames == ["Iris", "Milo"])
        #expect(longSummary.remainingHorseCount == 3)
    }
}
