import Testing
@testable import FarrierFlow

@Suite("USD price parsing")
struct USDPriceParserTests {
    @Test(arguments: [
        ("0", Int64(0)),
        ("12", Int64(1_200)),
        ("12.", Int64(1_200)),
        ("12.5", Int64(1_250)),
        ("12.50", Int64(1_250)),
        ("$12.50", Int64(1_250)),
        ("1,250.00", Int64(125_000)),
        ("  $1,250.50  ", Int64(125_050)),
        ("92,233,720,368,547,758.07", Int64.max),
    ])
    func parsesExactAcceptedUSPrice(_ input: String, expectedMinorUnits: Int64) throws {
        #expect(try USDPriceParser.parse(input) == expectedMinorUnits)
    }

    @Test(arguments: [
        "", "   ", "$", "-12", "+12", "(12.50)", ".50", "12.500",
        "12,50", "1,25,000", "1,,250", "1e3", "USD 12", "12 USD",
        "12,50", "12 50", "$ 12.50", "twelve", "12.50.0",
    ])
    func rejectsInvalidUSPriceGrammar(_ input: String) {
        #expect(throws: USDPriceParsingError.invalidFormat) {
            _ = try USDPriceParser.parse(input)
        }
    }

    @Test
    func rejectsCentsThatOverflowInt64() {
        #expect(throws: USDPriceParsingError.overflow) {
            _ = try USDPriceParser.parse("92,233,720,368,547,758.08")
        }
    }

    @Test
    func producesUSEditableAmountWithoutFloatingPoint() {
        #expect(USDPriceParser.editableString(minorUnits: 1_250) == "12.50")
        #expect(USDPriceParser.editableString(minorUnits: 0) == "0.00")
        #expect(USDPriceParser.editableString(minorUnits: -1) == nil)
    }
}
