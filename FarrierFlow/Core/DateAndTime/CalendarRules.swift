import Foundation

nonisolated enum CalendarRules {
    static func dayInterval(
        containing date: Date,
        calendar: Calendar
    ) -> DateInterval {
        guard let interval = calendar.dateInterval(of: .day, for: date) else {
            preconditionFailure("The calendar could not produce a local day interval.")
        }
        return interval
    }

    static func scheduleBoundary(now: Date, calendar: Calendar) -> Date {
        dayInterval(containing: now, calendar: calendar).start
    }
}
