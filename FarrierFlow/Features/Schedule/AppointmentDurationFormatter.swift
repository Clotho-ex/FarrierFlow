import Foundation

nonisolated enum AppointmentDurationFormatter {
    static func string(minutes: Int, locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .long
        let result = formatter.string(
            from: Measurement(
                value: Double(minutes),
                unit: UnitDuration.minutes
            )
        )

        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return String(localized: "Duration unavailable", locale: locale)
        }
        return result
    }
}
