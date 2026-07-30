import Foundation

nonisolated enum InvoiceDateRulesError: Error, Equatable {
    case unableToCalculateDueDate
}

nonisolated enum InvoiceDateRules {
    static func defaultDueDate(
        for invoiceDate: Date,
        calendar: Calendar
    ) throws -> Date {
        guard let dueDate = calendar.date(
            byAdding: .day,
            value: 14,
            to: invoiceDate
        ) else {
            throw InvoiceDateRulesError.unableToCalculateDueDate
        }
        return dueDate
    }
}
