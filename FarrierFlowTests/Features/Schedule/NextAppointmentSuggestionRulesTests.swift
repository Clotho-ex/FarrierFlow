import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Next appointment suggestion rules")
@MainActor
struct NextAppointmentSuggestionRulesTests {
    @Test
    func suggestsIntervalWeeksAtTheSourceAppointmentHourAndMinute() throws {
        let calendar = makeCalendar()
        let startedAt = try date(2026, 1, 5, 16, 45, calendar: calendar)
        let sourceStart = try date(2026, 1, 5, 9, 15, calendar: calendar)
        let expected = try date(2026, 2, 16, 9, 15, calendar: calendar)

        let suggestion = NextAppointmentSuggestionRules.suggestedStart(
            visitStartedAt: startedAt,
            intervalWeeks: 6,
            sourceAppointmentStart: sourceStart,
            calendar: calendar
        )

        #expect(suggestion == expected)
    }

    @Test
    func usesCalendarWeeksAcrossSpringForward() throws {
        let calendar = makeCalendar()
        let startedAt = try date(2026, 3, 2, 14, 30, calendar: calendar)
        let sourceStart = try date(2026, 3, 2, 9, 30, calendar: calendar)
        let expected = try date(2026, 3, 16, 9, 30, calendar: calendar)

        let suggestion = NextAppointmentSuggestionRules.suggestedStart(
            visitStartedAt: startedAt,
            intervalWeeks: 2,
            sourceAppointmentStart: sourceStart,
            calendar: calendar
        )

        #expect(suggestion == expected)
    }

    @Test
    func usesCalendarWeeksAcrossFallBack() throws {
        let calendar = makeCalendar()
        let startedAt = try date(2026, 10, 26, 14, 30, calendar: calendar)
        let sourceStart = try date(2026, 10, 26, 9, 30, calendar: calendar)
        let expected = try date(2026, 11, 9, 9, 30, calendar: calendar)

        let suggestion = NextAppointmentSuggestionRules.suggestedStart(
            visitStartedAt: startedAt,
            intervalWeeks: 2,
            sourceAppointmentStart: sourceStart,
            calendar: calendar
        )

        #expect(suggestion == expected)
    }

    @Test
    func doesNotSuggestANonpositiveInterval() throws {
        let calendar = makeCalendar()
        let workDate = try date(2026, 1, 5, 9, 0, calendar: calendar)

        #expect(NextAppointmentSuggestionRules.suggestedStart(
            visitStartedAt: workDate,
            intervalWeeks: 0,
            sourceAppointmentStart: workDate,
            calendar: calendar
        ) == nil)
        #expect(NextAppointmentSuggestionRules.suggestedStart(
            visitStartedAt: workDate,
            intervalWeeks: -1,
            sourceAppointmentStart: workDate,
            calendar: calendar
        ) == nil)
    }

    @Test
    func usesTheEarliestSelectedSuggestionForTheGroup() throws {
        let calendar = makeCalendar()
        let earliest = try date(2026, 2, 2, 9, 0, calendar: calendar)
        let later = try date(2026, 2, 16, 9, 0, calendar: calendar)

        #expect(NextAppointmentSuggestionRules.groupSuggestedStart(
            selectedSuggestedDates: [later, earliest]
        ) == earliest)
        #expect(NextAppointmentSuggestionRules.groupSuggestedStart(
            selectedSuggestedDates: []
        ) == nil)
    }

    @Test
    func keepsASuggestionExactlyAtNowForTheEditor() throws {
        let calendar = makeCalendar()
        let now = try date(2026, 2, 2, 9, 0, calendar: calendar)

        #expect(NextAppointmentSuggestionRules.editorStart(
            groupSuggestion: now,
            now: now,
            calendar: calendar
        ) == now)
    }

    @Test
    func usesTheNextHalfHourWhenTheGroupSuggestionIsPast() throws {
        let calendar = makeCalendar()
        let now = try date(2026, 2, 2, 9, 7, calendar: calendar)
        let historicalSuggestion = try date(2026, 2, 2, 9, 0, calendar: calendar)
        let expected = try date(2026, 2, 2, 9, 30, calendar: calendar)

        #expect(NextAppointmentSuggestionRules.editorStart(
            groupSuggestion: historicalSuggestion,
            now: now,
            calendar: calendar
        ) == expected)
        #expect(NextAppointmentSuggestionRules.editorStart(
            groupSuggestion: nil,
            now: now,
            calendar: calendar
        ) == expected)
    }

    @Test
    func rejectsTheSourceVisitFromRecencyPrecedence() throws {
        let identifiers = try makeIdentifiers(count: 2)
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        let completedAt = Date(timeIntervalSinceReferenceDate: 200)
        let source = try #require(CompletedVisitRecency(
            visitID: identifiers[0],
            startedAt: startedAt,
            completedAt: completedAt
        ))
        let candidate = try #require(CompletedVisitRecency(
            visitID: identifiers[1],
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            completedAt: Date(timeIntervalSinceReferenceDate: 400)
        ))

        #expect(!CompletedVisitRecency.precedes(
            source,
            source,
            sourceVisitID: source.visitID
        ))
        #expect(CompletedVisitRecency.precedes(
            candidate,
            source,
            sourceVisitID: source.visitID
        ))
    }

    @Test
    func ordersNewerVisitsByStartedThenCompletionTime() throws {
        let identifiers = try makeIdentifiers(count: 3)
        let source = try #require(CompletedVisitRecency(
            visitID: identifiers[0],
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200)
        ))
        let newerStart = try #require(CompletedVisitRecency(
            visitID: identifiers[1],
            startedAt: Date(timeIntervalSinceReferenceDate: 101),
            completedAt: Date(timeIntervalSinceReferenceDate: 150)
        ))
        let newerCompletion = try #require(CompletedVisitRecency(
            visitID: identifiers[2],
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 201)
        ))

        #expect(CompletedVisitRecency.precedes(
            newerStart,
            source,
            sourceVisitID: source.visitID
        ))
        #expect(CompletedVisitRecency.precedes(
            newerCompletion,
            source,
            sourceVisitID: source.visitID
        ))
        #expect(!CompletedVisitRecency.precedes(
            source,
            newerStart,
            sourceVisitID: newerStart.visitID
        ))
    }

    @Test
    func ordersEqualTimestampsByAscendingPersistentIdentifier() throws {
        let identifiers = try makeIdentifiers(count: 2).sorted()
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        let completedAt = Date(timeIntervalSinceReferenceDate: 200)
        let lowerIdentifier = try #require(CompletedVisitRecency(
            visitID: identifiers[0],
            startedAt: startedAt,
            completedAt: completedAt
        ))
        let higherIdentifier = try #require(CompletedVisitRecency(
            visitID: identifiers[1],
            startedAt: startedAt,
            completedAt: completedAt
        ))

        #expect(CompletedVisitRecency.precedes(
            lowerIdentifier,
            higherIdentifier,
            sourceVisitID: higherIdentifier.visitID
        ))
        #expect(!CompletedVisitRecency.precedes(
            higherIdentifier,
            lowerIdentifier,
            sourceVisitID: lowerIdentifier.visitID
        ))
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
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
}
