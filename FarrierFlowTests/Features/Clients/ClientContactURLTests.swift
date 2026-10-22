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
        let address = "client@example.com?bcc=other@example.com#notes"
        let url = try #require(ClientContactURL.email(address))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == address)
        #expect(components.query == nil)
        #expect(components.fragment == nil)
    }

    @Test(arguments: ["", " ", "No email", "client@example.com\nBcc:other@example.com"])
    func missingOrInvalidEmailHasNoMailAction(_ value: String) {
        #expect(ClientContactURL.email(value) == nil)
    }
}
