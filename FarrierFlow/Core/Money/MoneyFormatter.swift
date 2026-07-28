import Foundation

nonisolated enum MoneyFormatter {
    static func usd(minorUnits: Int64, locale: Locale = .current) -> String? {
        guard minorUnits >= 0 else {
            return nil
        }
        guard minorUnits != 0 else {
            return String(localized: "Complimentary")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = locale
        let amount = NSDecimalNumber(decimal: Decimal(minorUnits) / Decimal(100))
        return formatter.string(from: amount)
    }
}
