import AuthenticationServices
import CryptoKit
import Foundation
import Security

nonisolated enum AppleSignInChallengeError: Error, Equatable {
    case invalidEntropyLength
    case randomGenerationFailed
}

nonisolated struct AppleSignInChallenge: Sendable {
    let rawNonce: String
    private let hashedNonce: String

    init(
        randomData: (Int) throws -> Data = AppleSignInChallenge.secureRandomData
    ) throws {
        let data = try randomData(32)
        guard data.count == 32 else { throw AppleSignInChallengeError.invalidEntropyLength }
        rawNonce = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        hashedNonce = SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email]
        request.nonce = hashedNonce
    }

    private static func secureRandomData(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, address)
        }
        guard status == errSecSuccess else {
            throw AppleSignInChallengeError.randomGenerationFailed
        }
        return data
    }
}
