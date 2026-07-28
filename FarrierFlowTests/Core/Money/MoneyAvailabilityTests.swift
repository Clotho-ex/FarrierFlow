import Foundation
import Testing
@testable import FarrierFlow

@Suite("Money formatting")
struct MoneyAvailabilityTests {
    @Test
    func formatsZeroAsLocalizedComplimentaryCopy() {
        #expect(
            MoneyFormatter.usd(
                minorUnits: 0,
                locale: Locale(identifier: "en_US")
            ) == "Complimentary"
        )
    }

    @Test
    func formatsNonzeroMinorUnitsAsLocalizedUSDCurrency() {
        #expect(
            MoneyFormatter.usd(
                minorUnits: 1_250,
                locale: Locale(identifier: "en_US")
            ) == "$12.50"
        )
    }

    @Test
    func declinesNegativePersistenceValues() {
        #expect(MoneyFormatter.usd(minorUnits: -1, locale: .current) == nil)
    }
}
