import Foundation
import Testing
@testable import FarrierFlow

@Suite("Appointment duration formatting")
struct AppointmentDurationFormatterTests {
    @Test
    func formatsSingularAndPluralMinutesForEnglish() {
        let locale = Locale(identifier: "en_US")

        #expect(AppointmentDurationFormatter.string(minutes: 1, locale: locale) == "1 minute")
        #expect(AppointmentDurationFormatter.string(minutes: 45, locale: locale) == "45 minutes")
    }

    @Test
    func formatsMinutesUsingTheRequestedLocale() {
        let locale = Locale(identifier: "tr_TR")

        #expect(AppointmentDurationFormatter.string(minutes: 45, locale: locale) == "45 dakika")
    }

    @Test
    func formatsTheOriginalIntegerOverflowBoundaryWithoutTrapping() {
        let locale = Locale(identifier: "en_US")
        let firstOverflowingIntegerProduct = Int.max / 60 + 1

        let result = AppointmentDurationFormatter.string(
            minutes: firstOverflowingIntegerProduct,
            locale: locale
        )

        #expect(!result.isEmpty)
    }

    @Test
    func formatsMaximumIntegerWithoutTrapping() {
        let result = AppointmentDurationFormatter.string(
            minutes: Int.max,
            locale: Locale(identifier: "en_US")
        )

        #expect(!result.isEmpty)
    }

    @Test
    func everyPositiveBoundarySampleProducesNonemptyOutput() {
        let locale = Locale(identifier: "en_US")
        let values = [
            1,
            45,
            Int.max / 60,
            Int.max / 60 + 1,
            Int.max
        ]

        for value in values {
            #expect(!AppointmentDurationFormatter.string(
                minutes: value,
                locale: locale
            ).isEmpty)
        }
    }
}
