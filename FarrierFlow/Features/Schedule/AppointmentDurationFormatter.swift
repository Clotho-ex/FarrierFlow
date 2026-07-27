import Foundation

nonisolated enum AppointmentDurationFormatter {
    static func string(minutes: Int, locale: Locale) -> String {
        Duration.seconds(minutes * 60)
            .formatted(
                .units(
                    allowed: [.minutes],
                    width: .wide
                )
                .locale(locale)
            )
    }
}
