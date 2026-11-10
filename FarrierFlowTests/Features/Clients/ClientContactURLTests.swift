import Foundation
import Testing
@testable import FarrierFlow

@Suite("Client contact actions")
@MainActor
struct ClientContactURLTests {
    @Test
    func formattedPhoneUsesTheSavedNumberWithoutDisplayPunctuation() throws {
        let url = try #require(ClientContactURL.phone(" +1 (123) 456-78 "))
        #expect(url.absoluteString == "tel:+112345678")
    }

    @Test(arguments: ["", " ()-.", "Ask at the barn", "https://example.com", "+123#456"])
    func nonDialableContactTextHasNoCallAction(_ value: String) {
        #expect(ClientContactURL.phone(value) == nil)
    }

    @Test(arguments: ["++15550100", "555+0100", "+", "12", "+1234567890123456", "5550100,", "5550100;", ",5550100", ";5550100", "5550100,123,", "5550100;+123"])
    func malformedOrIncompleteNumbersHaveNoCallAction(_ value: String) {
        #expect(ClientContactURL.phone(value) == nil)
    }

    @Test(arguments: [
        ("+44 7700 900123", "tel:+447700900123"),
        ("+90 (532) 555 01 24", "tel:+905325550124"),
        ("555-0100,123", "tel:5550100,123"),
        ("555-0100;123", "tel:5550100;123")
    ])
    func internationalAndExtensionNumbersRetainTheirDialingMeaning(_ pair: (String, String)) throws {
        #expect(try #require(ClientContactURL.phone(pair.0)).absoluteString == pair.1)
    }

    @Test
    func emailPreservesPlusAddressingAndUnicode() throws {
        let address = "josé+appointments@example.com"
        let url = try #require(ClientContactURL.email(" \(address)\n"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == address)
    }

    @Test
    func contactTextCannotAddMailHeadersOrAFragment() throws {
        let address = "client?invoices#tag@example.com"
        let url = try #require(ClientContactURL.email(address))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == address)
        #expect(components.query == nil)
        #expect(components.fragment == nil)
    }

    @Test(arguments: ["", " ", "No email", "client@example.com\nBcc:other@example.com", "client@example.com?bcc=other@example.com#notes"])
    func missingOrInvalidEmailHasNoMailAction(_ value: String) {
        #expect(ClientContactURL.email(value) == nil)
    }
}
