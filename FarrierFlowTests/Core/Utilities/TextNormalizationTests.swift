import Testing
@testable import FarrierFlow

@Suite("Text normalization")
struct TextNormalizationTests {
    @Test
    func requiredTrimsBoundaryWhitespace() {
        #expect(TextNormalization.required(" \n Alex   Carter \t") == "Alex   Carter")
    }

    @Test(arguments: ["", " ", "\n\t"])
    func requiredRejectsEmptyNormalizedText(_ value: String) {
        #expect(TextNormalization.required(value) == nil)
    }

    @Test
    func optionalReturnsNilForEmptyNormalizedText() {
        #expect(TextNormalization.optional(" \n\t ") == nil)
    }

    @Test
    func optionalPreservesInternalSpacing() {
        #expect(TextNormalization.optional("  North   Field  ") == "North   Field")
    }
}
