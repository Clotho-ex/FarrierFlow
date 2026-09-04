import Testing
@testable import FarrierFlow

@Suite("Onboarding business name rules")
struct OnboardingBusinessNameRulesTests {
    @Test
    func acceptsAndNormalizesLettersNumbersAndSpaces() throws {
        let name = try OnboardingBusinessNameRules.validated(
            "  Carter Farrier Service 2  "
        )

        #expect(name == "Carter Farrier Service 2")
    }

    @Test
    func rejectsMissingName() {
        #expect(throws: OnboardingBusinessNameValidationError.required) {
            _ = try OnboardingBusinessNameRules.validated("   ")
        }
    }

    @Test(arguments: [
        "Carter & Son",
        "O'Brien Farrier",
        "High-Plains Farrier",
        "Carter 🐴 Farrier",
    ])
    func rejectsPunctuationSymbolsAndEmoji(name: String) {
        #expect(
            throws: OnboardingBusinessNameValidationError.unsupportedCharacters
        ) {
            _ = try OnboardingBusinessNameRules.validated(name)
        }
    }

    @Test
    func rejectsWholeWordVulgarityWithoutSubstringFalsePositives() throws {
        #expect(throws: OnboardingBusinessNameValidationError.vulgarity) {
            _ = try OnboardingBusinessNameRules.validated("Shit Farrier")
        }

        #expect(
            try OnboardingBusinessNameRules.validated("Scunthorpe Farrier")
                == "Scunthorpe Farrier"
        )
    }
}
