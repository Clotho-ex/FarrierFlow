import Foundation

nonisolated enum AppointmentIntervalFormatter {
    static func string(weeks: Int, locale: Locale) -> String {
        String(
            localized: "\(weeks) weeks",
            bundle: localizedBundle(for: locale),
            locale: locale
        )
    }

    private static func localizedBundle(for locale: Locale) -> Bundle {
        guard
            let localization = Bundle.preferredLocalizations(
                from: Bundle.main.localizations,
                forPreferences: [locale.identifier]
            ).first,
            let path = Bundle.main.path(
                forResource: localization,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}
