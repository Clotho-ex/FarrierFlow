import Foundation
import Testing
@testable import FarrierFlow

@Suite("Invoice date rules", .serialized)
struct InvoiceDateRulesTests {
    @Test
    func defaultDueDateAddsFourteenCalendarDaysAcrossDaylightSavingTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let invoiceDate = try #require(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 3,
                day: 7,
                hour: 12
            ))
        )
        let expectedDueDate = try #require(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 3,
                day: 21,
                hour: 12
            ))
        )

        #expect(
            try InvoiceDateRules.defaultDueDate(
                for: invoiceDate,
                calendar: calendar
            ) == expectedDueDate
        )
    }
}
