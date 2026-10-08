import Foundation

nonisolated enum BusinessCurrency: String, CaseIterable, Identifiable, Sendable {
    case unitedStatesDollar = "USD"
    case turkishLira = "TRY"
    case britishPound = "GBP"
    case euro = "EUR"
    case canadianDollar = "CAD"
    case australianDollar = "AUD"
    case newZealandDollar = "NZD"
    case southAfricanRand = "ZAR"

    var id: String { rawValue }

    static func isSupported(_ currencyCode: String) -> Bool {
        Self(rawValue: currencyCode) != nil
    }

    static func defaultCode(for locale: Locale) -> String {
        guard
            let localeCode = locale.currency?.identifier,
            let currency = Self(rawValue: localeCode.uppercased())
        else {
            return Self.unitedStatesDollar.rawValue
        }
        return currency.rawValue
    }

    func localizedName(in locale: Locale) -> String {
        locale.localizedString(forCurrencyCode: rawValue) ?? rawValue
    }

    var formattingLocale: Locale {
        switch self {
        case .unitedStatesDollar:
            Locale(identifier: "en_US")
        case .turkishLira:
            Locale(identifier: "tr_TR")
        case .britishPound:
            Locale(identifier: "en_GB")
        case .euro:
            Locale(identifier: "en_IE")
        case .canadianDollar:
            Locale(identifier: "en_CA")
        case .australianDollar:
            Locale(identifier: "en_AU")
        case .newZealandDollar:
            Locale(identifier: "en_NZ")
        case .southAfricanRand:
            Locale(identifier: "en_ZA")
        }
    }
}
