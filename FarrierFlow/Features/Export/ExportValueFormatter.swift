import Foundation

nonisolated enum ExportValueFormatter {
    static func utc(_ date: Date) -> String {
        let parts = secondAndMicrosecond(for: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return "\(formatter.string(from: parts.second))\(String(format: ".%06dZ", parts.microsecond))"
    }

    static func local(_ date: Date, context: ExportContext) -> String {
        let parts = secondAndMicrosecond(for: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: context.localeIdentifier)
        formatter.calendar = Calendar(identifier: context.calendarIdentifier)
        formatter.timeZone = TimeZone(identifier: context.timeZoneIdentifier) ?? .gmt
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let localDate = formatter.string(from: parts.second)
        formatter.dateFormat = "xxxxx"
        let offset = formatter.string(from: parts.second)
        return "\(localDate)\(String(format: ".%06d", parts.microsecond))\(offset)"
    }

    static func boolean(_ value: Bool) -> String { value ? "true" : "false" }

    static func usdDisplay(minorUnits: Int64, localeIdentifier: String) -> String? {
        guard minorUnits >= 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positiveFormat = "¤#,##0.00"
        let amount = Decimal(minorUnits) / 100
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }

    private static func secondAndMicrosecond(for date: Date) -> (second: Date, microsecond: Int64) {
        let interval = date.timeIntervalSince1970
        var wholeSeconds = Int64(floor(interval))
        var microseconds = Int64(((interval - Double(wholeSeconds)) * 1_000_000).rounded())
        if microseconds == 1_000_000 {
            wholeSeconds += 1
            microseconds = 0
        }
        return (Date(timeIntervalSince1970: TimeInterval(wholeSeconds)), microseconds)
    }
}
