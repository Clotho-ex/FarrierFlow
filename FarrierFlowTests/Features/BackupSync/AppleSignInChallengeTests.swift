import AuthenticationServices
import Foundation
import Testing
@testable import FarrierFlow

@Suite("Native Apple sign-in nonce")
@MainActor
struct AppleSignInChallengeTests {
    @Test
    func appleRequestReceivesHashWhileTokenExchangeKeepsRawNonce() throws {
        let challenge = try AppleSignInChallenge(randomData: { length in
            #expect(length == 32)
            return Data((0..<32).map(UInt8.init))
        })
        let request = ASAuthorizationAppleIDProvider().createRequest()
        challenge.configure(request)
        #expect(challenge.rawNonce == "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
        #expect(request.nonce == "ea866a757e4c38babfa8127cbe9a409d3e1f93a00ff1488ff735fcf917afffd0")
        #expect(request.requestedScopes == [.email])
    }

    @Test
    func randomFailureCannotFallBackToPredictableNonce() {
        #expect(throws: RandomFailure.unavailable) {
            try AppleSignInChallenge(randomData: { _ in throw RandomFailure.unavailable })
        }
    }

    @Test
    func insufficientEntropyIsRejected() {
        #expect(throws: AppleSignInChallengeError.invalidEntropyLength) {
            try AppleSignInChallenge(randomData: { _ in Data([1, 2]) })
        }
    }

    @Test
    func productionChallengesAreDistinctAndURLSafe() throws {
        let first = try AppleSignInChallenge()
        let second = try AppleSignInChallenge()
        #expect(first.rawNonce != second.rawNonce)
        #expect(first.rawNonce.count == 43)
        #expect(first.rawNonce.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil)
    }

    private enum RandomFailure: Error, Equatable { case unavailable }
}
