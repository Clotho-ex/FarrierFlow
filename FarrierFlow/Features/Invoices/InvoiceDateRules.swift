import Foundation

nonisolated enum InvoiceDateRulesError: Error, Equatable {
    case unableToCalculateDueDate
}

nonisolated enum InvoiceDateRules {
    static func defaultDueDate(
        for invoiceDate: Date,
        days: Int,
        calendar: Calendar
    ) throws -> Date {
        guard days > 0, let dueDate = calendar.date(
            byAdding: .day,
            value: days,
            to: invoiceDate
        ) else {
            throw InvoiceDateRulesError.unableToCalculateDueDate
        }
        return dueDate
    }

    static func defaultDueDate(
        for invoiceDate: Date,
        calendar: Calendar
    ) throws -> Date {
        try defaultDueDate(for: invoiceDate, days: 14, calendar: calendar)
    }
}
