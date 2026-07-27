import Foundation

nonisolated enum AppointmentIntervalFormatter {
    static func string(weeks: Int, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.weekOfMonth]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar

        return formatter.string(
            from: DateComponents(weekOfMonth: weeks)
        ) ?? String(localized: "\(weeks) weeks", locale: locale)
    }
}
