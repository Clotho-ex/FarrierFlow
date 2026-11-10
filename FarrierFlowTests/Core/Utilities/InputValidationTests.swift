import Foundation
import Testing
@testable import FarrierFlow

@Suite("Editor input validation")
struct InputValidationTests {
    @Test(arguments: ["alex@example.com", "alex+invoices@example.co.uk", "josé@example.com", "client@例子.公司", "a.b-c_d@farrier.business"])
    func acceptsCommonAddresses(_ email: String) {
        #expect(EmailAddress.isValid(email))
    }

    @Test(arguments: ["plain text", "a@", "@example.com", "a@@example.com", "a@localhost", "a..b@example.com", ".a@example.com", "a.@example.com", "a@-example.com", "a@example-.com", "a@example..com", "a@example.c", "a@example.123", "a b@example.com", "a@example.com?bcc=other@example.com", "a@example.com#notes", "a@example.com\nBcc:other@example.com"])
    func rejectsMalformedAddresses(_ email: String) {
        #expect(!EmailAddress.isValid(email))
    }

    @Test
    func emailLengthAndOptionalValues() {
        #expect(EmailAddress.isValidOptional(" \n"))
        #expect(EmailAddress.isValid(String(repeating: "a", count: 64) + "@example.com"))
        #expect(!EmailAddress.isValid(String(repeating: "a", count: 65) + "@example.com"))
    }

    @Test
    func editorEmailLimitDoesNotDependOnSyntaxFailure() {
        let address = String(repeating: "a", count: 64) + "@" + String(repeating: "b", count: 32) + ".com"
        #expect(address.count == 101)
        #expect(EmailAddress.isValid(address))
        #expect(!ClientDraft(name: "Alex", email: address).isValid)
    }

    @Test
    func limitsPreserveWholeCharactersAndExistingText() {
        let emoji = "👨‍👩‍👧‍👦"
        #expect(InputLimits.accepting("12345678901234567", previous: "50.00", maximum: InputLimits.price, rejectOverflow: true) == "50.00")
        #expect(InputLimits.accepting(emoji + "abc", previous: "", maximum: 2) == emoji + "a")
        #expect(InputLimits.accepting("over-limit@example.com", previous: "a@b.co", maximum: 10, rejectOverflow: true) == "a@b.co")
        #expect(InputLimits.accepting("abcdefgh", previous: "abcdefg", maximum: 5) == "abcdefg")
        #expect(InputLimits.accepting("abcdef", previous: "abcdefg", maximum: 5) == "abcdef")
    }
}
