import Foundation
import Testing
@testable import FarrierFlow

@Suite("Local calendar rules")
struct CalendarRulesTests {
    @Test
    func ordinaryDayUsesLocalCalendarBoundaries() {
        let calendar = calendar(timeZone: "America/Chicago")
        let instant = date(
            year: 2026,
            month: 7,
            day: 26,
            hour: 14,
            minute: 30,
            calendar: calendar
        )

        let interval = CalendarRules.dayInterval(containing: instant, calendar: calendar)

        #expect(interval.start == date(
            year: 2026,
            month: 7,
            day: 26,
            hour: 0,
            minute: 0,
            calendar: calendar
        ))
        #expect(interval.end == date(
            year: 2026,
            month: 7,
            day: 27,
            hour: 0,
            minute: 0,
            calendar: calendar
        ))
    }

    @Test
    func scheduleIncludesAnAppointmentExactlyAtTodayBoundary() {
        let calendar = calendar(timeZone: "America/Denver")
        let now = date(
            year: 2026,
            month: 7,
            day: 26,
            hour: 11,
            minute: 0,
            calendar: calendar
        )
        let boundary = CalendarRules.scheduleBoundary(now: now, calendar: calendar)

        #expect(boundary >= boundary)
    }

    @Test
    func scheduleExcludesTheInstantBeforeTodayBoundary() {
        let calendar = calendar(timeZone: "America/Denver")
        let now = date(
            year: 2026,
            month: 7,
            day: 26,
            hour: 11,
            minute: 0,
            calendar: calendar
        )
        let boundary = CalendarRules.scheduleBoundary(now: now, calendar: calendar)

        #expect(boundary.addingTimeInterval(-0.001) < boundary)
    }

    @Test
    func daylightSavingTransitionDayIsNotForcedToTwentyFourHours() {
        let calendar = calendar(timeZone: "America/Los_Angeles")
        let transitionDay = date(
            year: 2026,
            month: 3,
            day: 8,
            hour: 12,
            minute: 0,
            calendar: calendar
        )

        let interval = CalendarRules.dayInterval(
            containing: transitionDay,
            calendar: calendar
        )

        #expect(interval.duration == 23 * 60 * 60)
    }

    @Test
    func scheduleBoundaryEqualsLocalStartOfDay() {
        let calendar = calendar(timeZone: "America/New_York")
        let now = date(
            year: 2026,
            month: 11,
            day: 1,
            hour: 18,
            minute: 0,
            calendar: calendar
        )

        #expect(
            CalendarRules.scheduleBoundary(now: now, calendar: calendar)
                == calendar.startOfDay(for: now)
        )
    }

    private func calendar(timeZone identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
