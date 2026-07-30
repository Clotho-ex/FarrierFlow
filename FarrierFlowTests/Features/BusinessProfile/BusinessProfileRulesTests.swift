import Testing
@testable import FarrierFlow

@Suite("Business Profile rules", .serialized)
struct BusinessProfileRulesTests {
    @Test
    func validatesAndNormalizesEveryEditableField() throws {
        let values = try BusinessProfileRules.validated(
            BusinessProfileDraft(
                name: "  Carter Farrier Service \n",
                phone: "  555-0100  ",
                email: "  alex@example.com\n",
                address: "\n1 Main Street  ",
                defaultInvoiceNote: "  Thank you for your business. \n"
            )
        )

        #expect(values == BusinessProfileValues(
            name: "Carter Farrier Service",
            phone: "555-0100",
            email: "alex@example.com",
            address: "1 Main Street",
            defaultInvoiceNote: "Thank you for your business."
        ))
    }

    @Test
    func rejectsAMissingBusinessOrFarrierName() {
        #expect(throws: BusinessProfileRulesError.nameRequired) {
            _ = try BusinessProfileRules.validated(
                BusinessProfileDraft(name: " \n\t")
            )
        }
    }

    @Test
    func clearingOptionalFieldsProducesNilValues() throws {
        let values = try BusinessProfileRules.validated(
            BusinessProfileDraft(
                name: "Carter Farrier Service",
                phone: " ",
                email: "\n",
                address: "",
                defaultInvoiceNote: "  "
            )
        )

        #expect(values.phone == nil)
        #expect(values.email == nil)
        #expect(values.address == nil)
        #expect(values.defaultInvoiceNote == nil)
    }
}
