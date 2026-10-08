import Foundation
import Testing
@testable import FarrierFlow

@Suite("Money formatting")
struct MoneyAvailabilityTests {
    @Test
    func formatsZeroAsLocalizedComplimentaryCopy() {
        #expect(
            MoneyFormatter.currency(
                minorUnits: 0,
                currencyCode: "GBP",
                locale: Locale(identifier: "en_US")
            ) == "Complimentary"
        )
    }

    @Test
    func formatsNonzeroMinorUnitsAsStoredCurrency() {
        #expect(
            MoneyFormatter.currency(
                minorUnits: 1_250,
                currencyCode: "GBP",
                locale: Locale(identifier: "en_GB")
            ) == "£12.50"
        )
    }

    @Test
    func declinesNegativeOrUnsupportedPersistenceValues() {
        #expect(
            MoneyFormatter.currency(
                minorUnits: -1,
                currencyCode: "USD",
                locale: .current
            ) == nil
        )
        #expect(
            MoneyFormatter.currency(
                minorUnits: 1_250,
                currencyCode: "JPY",
                locale: .current
            ) == nil
        )
    }
}
