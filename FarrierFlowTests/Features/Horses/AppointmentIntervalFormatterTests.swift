import Foundation
import Testing
@testable import FarrierFlow

@Suite("Appointment interval formatting")
struct AppointmentIntervalFormatterTests {
    @Test
    func formatsSingularAndPluralWeeksForEnglish() {
        let locale = Locale(identifier: "en_US")

        #expect(AppointmentIntervalFormatter.string(weeks: 1, locale: locale) == "1 week")
        #expect(AppointmentIntervalFormatter.string(weeks: 6, locale: locale) == "6 weeks")
    }

    @Test
    func formatsWeeksUsingTheRequestedLocale() {
        let result = AppointmentIntervalFormatter.string(
            weeks: 6,
            locale: Locale(identifier: "tr_TR")
        )

        #expect(result == "6 hafta")
    }

    @Test
    func positiveValuesProduceNonemptyOutput() {
        let locale = Locale(identifier: "en_US")

        for value in [1, 6, 52, Int.max] {
            #expect(!AppointmentIntervalFormatter.string(
                weeks: value,
                locale: locale
            ).isEmpty)
        }
    }
}
