import Testing
@testable import FarrierFlow

@Suite("Phone number formatting")
@MainActor
struct PhoneNumberFormattingTests {
    @Test(arguments: [("2025550143", "US", "+12025550143"), ("0872278701", "IE", "+353872278701"), ("05321234567", "TR", "+905321234567"), ("07700900123", "GB", "+447700900123")])
    func normalizesNewRegionalInput(_ value: (String, String, String)) {
        #expect(PhoneNumberFormatting.normalized(value.0, region: value.1) == value.2)
        #expect(PhoneNumberFormatting.normalized(PhoneNumberFormatting.formattedInput(value.0, region: value.1), region: value.1) == value.2)
    }

    @Test
    func countryCodeOverridesPhoneRegionAndPostDialIsPreserved() {
        #expect(PhoneNumberFormatting.normalized("+353 87 227 8701", region: "US") == "+353872278701")
        #expect(PhoneNumberFormatting.normalized("+1 202-555-0143;123", region: "TR") == "+12025550143;123")
        #expect(PhoneNumberFormatting.display("+12025550143") == "+1 202-555-0143")
    }

    @Test(arguments: ["555-0100", "Ask at the barn", "12", "", "07700 900123"])
    func existingLocalOrInvalidTextIsNotReinterpreted(_ value: String) {
        #expect(PhoneNumberFormatting.display(value) == value)
    }
}
