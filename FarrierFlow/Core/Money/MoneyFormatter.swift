import Foundation
import Synchronization

nonisolated enum MoneyFormatter {
    private struct FormatKey: Hashable {
        let currencyCode: String
        let locale: Locale
    }

    private static let formatters = Mutex<[FormatKey: NumberFormatter]>([:])

    static func currency(
        minorUnits: Int64,
        currencyCode: String,
        locale: Locale = .current,
        showsZeroAsComplimentary: Bool = true
    ) -> String? {
        guard minorUnits >= 0, BusinessCurrency.isSupported(currencyCode) else {
            return nil
        }
        guard minorUnits != 0 || !showsZeroAsComplimentary else {
            return String(localized: "Complimentary")
        }

        let amount = NSDecimalNumber(decimal: Decimal(minorUnits) / Decimal(100))
        return formatters.withLock { cache in
            let key = FormatKey(currencyCode: currencyCode, locale: locale)
            let formatter: NumberFormatter
            if let existing = cache[key] {
                formatter = existing
            } else {
                formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.currencyCode = currencyCode
                formatter.locale = locale
                if cache.count >= 32 { cache.removeAll(keepingCapacity: true) }
                cache[key] = formatter
            }
            return formatter.string(from: amount)
        }
    }
}
