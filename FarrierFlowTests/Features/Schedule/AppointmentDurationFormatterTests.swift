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
}
