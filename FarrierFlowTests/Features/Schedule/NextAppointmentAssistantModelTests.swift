import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Next appointment assistant model")
@MainActor
struct NextAppointmentAssistantModelTests {
    @Test
    func completedVisitProjectsEligibleHorsesAndCreatesAnImmutableSeed() throws {
        let graph = try makeSourceGraph(
            intervals: [6, 4, 8],
            outcomes: [.serviced, .serviced, .notServiced]
        )
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(in: graph.context, now: graph.now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        let projection = try #require(model.projection)
        #expect(model.loadState == .loaded)
        #expect(projection.options.map(\.outcome) == [.serviced, .serviced, .notServiced])
        #expect(projection.options.map(\.isSelected) == [true, true, false])
        #expect(projection.options.map(\.suggestedStart) == [
            date(2026, 2, 16, 9, 0, calendar: graph.calendar),
            date(2026, 2, 2, 9, 0, calendar: graph.calendar),
            nil
        ])
        #expect(projection.proposedStart == date(2026, 2, 2, 9, 0, calendar: graph.calendar))

        let seed = try #require(model.makeSeed())
        #expect(seed.barnID == graph.barnID)
        #expect(seed.horseIDs == Set(graph.horseIDs.prefix(2)))
        #expect(seed.startDate == projection.proposedStart)
        #expect(seed.hasFollowUpSuggestion)
    }

    @Test(arguments: SourceInvalidation.allCases)
    fileprivate func invalidSourceGraphFailsTheEntireProjection(_ invalidation: SourceInvalidation) throws {
        let graph = try makeSourceGraph()
        switch invalidation {
        case .missingAppointment:
            graph.visit.appointment = nil
        case .brokenInverse:
            graph.appointment.visit = nil
        case .locationMismatch:
            let otherBarn = Barn(name: "South Field")
            graph.context.insert(otherBarn)
            graph.visit.barn = otherBarn
        case .completionBeforeStart:
            graph.visit.completedAt = graph.visit.startedAt.addingTimeInterval(-1)
        case .duplicateMembership:
            let duplicate = AppointmentHorse(
                appointment: graph.appointment,
                horse: graph.horses[0]
            )
            graph.context.insert(duplicate)
            graph.appointment.appointmentHorses.append(duplicate)
        case .unequalMembership:
            graph.visit.visitHorses.removeLast()
        }
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(in: graph.context, now: graph.now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        #expect(model.loadState == .failed(.sourceAppointmentUnavailable))
        #expect(model.projection == nil)
        #expect(model.makeSeed() == nil)
    }

    @Test
    func currentGraphConditionsProduceIndependentHorseAvailability() throws {
        let graph = try makeSourceGraph(
            intervals: [6, 6, 0, 6, 6],
            outcomes: [.serviced, .serviced, .serviced, .serviced, .notServiced]
        )
        graph.horses[3].client = nil
        let movedBarn = Barn(name: "Moved Barn")
        graph.context.insert(movedBarn)
        graph.horses[4].currentBarn = movedBarn
        _ = ModelFixtures.makeAppointment(
            startDate: graph.now,
            barn: graph.barn,
            horses: [graph.horses[1]],
            in: graph.context
        )

        let newerAppointment = ModelFixtures.makeAppointment(
            startDate: graph.now.addingTimeInterval(-86_400),
            barn: graph.barn,
            horses: [graph.horses[0]],
            in: graph.context
        )
        let newerVisit = ModelFixtures.makeVisit(
            startedAt: graph.visit.startedAt.addingTimeInterval(86_400),
            completedAt: try #require(graph.visit.completedAt).addingTimeInterval(86_400),
            appointment: newerAppointment,
            in: graph.context
        )
        newerVisit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue

        let model = NextAppointmentAssistantModel(visitID: graph.visitID)
        model.load(in: graph.context, now: graph.now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        let options = try #require(model.projection?.options)
        #expect(options[0].unavailabilityReason == .newerServicedVisit)
        #expect(options[1].unavailabilityReason == .alreadyScheduled)
        #expect(options[2].unavailabilityReason == .invalidAppointmentInterval)
        #expect(options[3].unavailabilityReason == .clientUnavailable)
        #expect(options[4].unavailabilityReason == .moved)
        #expect(options.allSatisfy { !$0.isSelected })
    }

    @Test
    func sourceAppointmentIsNotItsOwnFutureDuplicateAndTheSourceVisitCannotSupersedeItself() throws {
        let graph = try makeSourceGraph()
        graph.appointment.startDate = graph.now
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(in: graph.context, now: graph.now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        let option = try #require(model.projection?.options.first)
        #expect(option.unavailabilityReason == nil)
        #expect(option.isSelected)
    }

    @Test
    func pastGroupFallbackAndSelectionChangesReuseTheCapturedNow() throws {
        let graph = try makeSourceGraph(intervals: [1, 6], outcomes: [.serviced, .serviced])
        let now = date(2026, 3, 20, 10, 10, calendar: graph.calendar)
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(in: graph.context, now: now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        let initial = try #require(model.projection)
        #expect(initial.options[0].suggestedStart == date(2026, 1, 12, 9, 0, calendar: graph.calendar))
        #expect(initial.proposedStart == date(2026, 3, 20, 10, 30, calendar: graph.calendar))

        model.toggleHorse(initial.options[1].id)
        #expect(model.projection?.proposedStart == date(2026, 3, 20, 10, 30, calendar: graph.calendar))
        model.setProposedStart(date(2026, 4, 1, 14, 0, calendar: graph.calendar))
        model.toggleHorse(initial.options[1].id)
        #expect(model.projection?.proposedStart == date(2026, 4, 1, 14, 0, calendar: graph.calendar))
    }

    @Test
    func partialSavedFollowUpDisablesOnlyScheduledHorsesAndFreshLoadsRestoreEligibility() throws {
        let graph = try makeSourceGraph(intervals: [6, 4, 8], outcomes: [.serviced, .serviced, .notServiced])
        let future = ModelFixtures.makeAppointment(
            startDate: graph.now,
            barn: graph.barn,
            horses: [graph.horses[0]],
            in: graph.context
        )
        let firstLoad = NextAppointmentAssistantModel(visitID: graph.visitID)
        firstLoad.load(in: graph.context, now: graph.now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        let firstProjection = try #require(firstLoad.projection)
        #expect(firstProjection.options.map(\.unavailabilityReason) == [.alreadyScheduled, nil, nil])
        #expect(firstProjection.options.map(\.isSelected) == [false, true, false])
        #expect(firstProjection.proposedStart == date(2026, 2, 2, 9, 0, calendar: graph.calendar))

        graph.context.delete(future)
        let secondLoad = NextAppointmentAssistantModel(visitID: graph.visitID)
        secondLoad.load(in: graph.context, now: graph.now, calendar: graph.calendar, locale: Locale(identifier: "en_US"))

        #expect(secondLoad.projection?.options.map(\.isSelected) == [true, true, false])
    }

    @Test
    func continueRequiresASelectedHorseAndTheAssistantAcceptsAVisitIdentifier() throws {
        let graph = try makeSourceGraph()
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(
            in: graph.context,
            now: graph.now,
            calendar: graph.calendar,
            locale: Locale(identifier: "en_US")
        )
        let option = try #require(model.projection?.options.first)
        model.toggleHorse(option.id)

        #expect(model.makeSeed() == nil)
        _ = NextAppointmentAssistantView(visitID: graph.visitID)
    }

    @Test
    func deselectingTheEarliestSuggestionUsesTheRemainingSelectedSuggestion() throws {
        let graph = try makeSourceGraph(
            intervals: [4, 6],
            outcomes: [.serviced, .serviced]
        )
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(
            in: graph.context,
            now: graph.now,
            calendar: graph.calendar,
            locale: Locale(identifier: "en_US")
        )

        let projection = try #require(model.projection)
        let earliest = try #require(projection.options[0].suggestedStart)
        let remaining = try #require(projection.options[1].suggestedStart)
        #expect(earliest < remaining)
        #expect(projection.proposedStart == earliest)

        model.toggleHorse(projection.options[0].id)

        #expect(model.projection?.options.map(\.isSelected) == [false, true])
        #expect(model.projection?.proposedStart == remaining)
    }

    @Test
    func calendarCalculationFailureUsesTheOrdinaryDraftFallback() throws {
        let graph = try makeSourceGraph(
            intervals: [calendarFailureInterval()],
            outcomes: [.serviced]
        )
        let model = NextAppointmentAssistantModel(visitID: graph.visitID)

        model.load(
            in: graph.context,
            now: graph.now,
            calendar: graph.calendar,
            locale: Locale(identifier: "en_US")
        )

        let projection = try #require(model.projection)
        let option = try #require(projection.options.first)
        let ordinaryDraftStart = AppointmentStartDateRules.nextHalfHour(
            after: graph.now,
            calendar: graph.calendar
        )
        #expect(option.isSelected)
        #expect(option.suggestedStart == nil)
        #expect(projection.proposedStart == ordinaryDraftStart)
        #expect(!projection.hasFollowUpSuggestion)

        let seed = try #require(model.makeSeed())
        #expect(seed.startDate == ordinaryDraftStart)
        #expect(!seed.hasFollowUpSuggestion)
    }
}

fileprivate enum SourceInvalidation: CaseIterable {
    case missingAppointment
    case brokenInverse
    case locationMismatch
    case completionBeforeStart
    case duplicateMembership
    case unequalMembership
}

private struct NextAppointmentAssistantTestGraph {
    let container: ModelContainer
    let context: ModelContext
    let calendar: Calendar
    let now: Date
    let barn: Barn
    let appointment: Appointment
    let visit: Visit
    let horses: [Horse]

    var barnID: PersistentIdentifier { barn.persistentModelID }
    var horseIDs: [PersistentIdentifier] { horses.map(\.persistentModelID) }
    var visitID: PersistentIdentifier { visit.persistentModelID }
}

@MainActor
private func makeSourceGraph(
    intervals: [Int] = [6],
    outcomes: [VisitOutcome] = [.serviced]
) throws -> NextAppointmentAssistantTestGraph {
    precondition(intervals.count == outcomes.count)
    let container = try ModelContainerFactory.inMemoryTest()
    let context = container.mainContext
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let sourceStart = date(2026, 1, 5, 9, 0, calendar: calendar)
    let now = date(2026, 1, 6, 10, 10, calendar: calendar)
    let barn = Barn(name: "North Field")
    context.insert(barn)

    let horses = zip(intervals.indices, zip(intervals, outcomes)).map { index, input in
        let client = Client(name: "Client \(index)")
        let horse = Horse(
            name: "Horse \(index)",
            appointmentIntervalWeeks: input.0,
            client: client,
            currentBarn: barn
        )
        context.insert(client)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        return horse
    }
    let appointment = ModelFixtures.makeAppointment(
        startDate: sourceStart,
        barn: barn,
        horses: horses,
        in: context
    )
    let visit = ModelFixtures.makeVisit(
        startedAt: date(2026, 1, 5, 11, 0, calendar: calendar),
        completedAt: date(2026, 1, 5, 12, 0, calendar: calendar),
        appointment: appointment,
        in: context
    )
    for (visitHorse, outcome) in zip(visit.visitHorses, outcomes) {
        visitHorse.outcomeRawValue = outcome.rawValue
        if outcome == .serviced {
            let service = ModelFixtures.makeService(in: context)
            _ = ModelFixtures.makeWorkItem(
                service: service,
                visitHorse: visitHorse,
                in: context
            )
        }
    }
    try DomainGraphValidator.save(context)

    return NextAppointmentAssistantTestGraph(
        container: container,
        context: context,
        calendar: calendar,
        now: now,
        barn: barn,
        appointment: appointment,
        visit: visit,
        horses: horses
    )
}

private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    calendar: Calendar
) -> Date {
    calendar.date(from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

private func calendarFailureInterval() -> Int {
    Int.max
}
