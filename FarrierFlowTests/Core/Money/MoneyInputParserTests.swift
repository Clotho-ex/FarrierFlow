import Foundation
import Testing
@testable import FarrierFlow

@Suite("Money input parsing")
struct MoneyInputParserTests {
    @Test(arguments: [
        ("0", "en_US", "USD", Int64(0)),
        ("12", "en_GB", "GBP", Int64(1_200)),
        ("12.5", "en_IE", "EUR", Int64(1_250)),
        ("£12.50", "en_GB", "GBP", Int64(1_250)),
        ("1,250.50", "en_CA", "CAD", Int64(125_050)),
        ("1.250,50", "tr_TR", "TRY", Int64(125_050)),
        ("92,233,720,368,547,758.07", "en_US", "USD", Int64.max),
    ])
    func parsesLocaleAwareAmounts(
        input: String,
        localeIdentifier: String,
        currencyCode: String,
        expectedMinorUnits: Int64
    ) throws {
        #expect(
            try MoneyInputParser.parse(
                input,
                currencyCode: currencyCode,
                locale: Locale(identifier: localeIdentifier)
            ) == expectedMinorUnits
        )
    }

    @Test(arguments: [
        "", "   ", "-12", "+12", ".50", "12.500", "1,25,000",
        "1,,250", "1e3", "12 USD", "12 50", "twelve", "12.50.0",
    ])
    func rejectsInvalidEnglishAmountGrammar(_ input: String) {
        #expect(throws: MoneyInputParsingError.invalidFormat) {
            _ = try MoneyInputParser.parse(
                input,
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            )
        }
    }

    @Test
    func rejectsUnsupportedCurrency() {
        #expect(throws: MoneyInputParsingError.unsupportedCurrency) {
            _ = try MoneyInputParser.parse(
                "12.50",
                currencyCode: "JPY",
                locale: Locale(identifier: "ja_JP")
            )
        }
    }

    @Test
    func rejectsMinorUnitsThatOverflowInt64() {
        #expect(throws: MoneyInputParsingError.overflow) {
            _ = try MoneyInputParser.parse(
                "92,233,720,368,547,758.08",
                currencyCode: "USD",
                locale: Locale(identifier: "en_US")
            )
        }
    }

    @Test
    func producesLocaleAwareEditableAmountsWithoutFloatingPoint() {
        #expect(
            MoneyInputParser.editableString(
                minorUnits: 1_250,
                locale: Locale(identifier: "en_US")
            ) == "12.50"
        )
        #expect(
            MoneyInputParser.editableString(
                minorUnits: 1_250,
                locale: Locale(identifier: "tr_TR")
            ) == "12,50"
        )
        #expect(
            MoneyInputParser.editableString(
                minorUnits: -1,
                locale: Locale(identifier: "en_US")
            ) == nil
        )
    }
}
