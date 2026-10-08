import Foundation

nonisolated enum MoneyFormatter {
    static func currency(
        minorUnits: Int64,
        currencyCode: String,
        locale: Locale = .current
    ) -> String? {
        guard minorUnits >= 0, BusinessCurrency.isSupported(currencyCode) else {
            return nil
        }
        guard minorUnits != 0 else {
            return String(localized: "Complimentary")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        let amount = NSDecimalNumber(decimal: Decimal(minorUnits) / Decimal(100))
        return formatter.string(from: amount)
    }
}
