import AuthenticationServices
import Foundation
import OSLog
import Supabase

nonisolated enum AppleSignInServiceError: Error, Equatable {
    case invalidIdentityToken
    case sessionNotStored
    case sessionNotCleared
    case notSignedIn
}

nonisolated struct AppleSignInService: CloudAccountAuthentication {
    let client: SupabaseClient
    private let operations = AppleSessionOperations()
    private let credentialIsAuthorized: @Sendable (String) async throws -> Bool

    init(client: SupabaseClient,
         credentialIsAuthorized: @escaping @Sendable (String) async throws -> Bool = Self.nativeCredentialIsAuthorized) {
        self.client = client
        self.credentialIsAuthorized = credentialIsAuthorized
    }

    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async throws -> UUID {
        try await operations.run { [client] in
            try Task.checkCancellation()
            return try await Self.exchange(client: client, identityToken: identityToken, challenge: challenge)
        }
    }

    private static func exchange(
        client: SupabaseClient, identityToken: Data, challenge: AppleSignInChallenge
    ) async throws -> UUID {
        guard !identityToken.isEmpty, identityToken.count <= 16_384,
              let token = String(data: identityToken, encoding: .utf8),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleSignInServiceError.invalidIdentityToken
        }
        let session = try await client.auth.signInWithIdToken(credentials: .init(
            provider: .apple, idToken: token, nonce: challenge.rawNonce
        ))
        do {
            try Task.checkCancellation()
        } catch {
            do { try await Self.clearSession(client) }
            catch {
                guard client.auth.currentSession == nil else { throw AppleSignInServiceError.sessionNotCleared }
                // The cancelled operation must not become auto-restorable.
                // Remote logout may fail offline; never log session values.
                Logger(subsystem: "com.farrierflow.yusufcan.FarrierFlow", category: "BackupSync")
                    .notice("Cancelled Apple exchange cleared locally; remote logout was not confirmed.")
            }
            throw CancellationError()
        }
        guard let persisted = client.auth.currentSession,
              persisted.user.id == session.user.id,
              persisted.accessToken == session.accessToken else {
            // SDK reports storage errors to its optional logger, not the
            // exchange caller. A returned session is not proof it was saved.
            throw AppleSignInServiceError.sessionNotStored
        }
        return session.user.id
    }

    func currentAccountID() async throws -> UUID {
        // Unlike currentSession, this refreshes an expired session and does
        // not treat a cached account as proof of current cloud access.
        do {
            return try await operations.run { [client, credentialIsAuthorized] in
                try Task.checkCancellation()
                let session = try await client.auth.session
                try Task.checkCancellation()
                let identities = session.user.identities?.filter { $0.provider == "apple" && $0.userId == session.user.id } ?? []
                guard identities.count == 1, let identity = identities.first,
                      case .string(let subject)? = identity.identityData?["sub"],
                      !subject.isEmpty, subject.count <= 255 else {
                    try await Self.clearRevokedSession(client)
                    throw AppleSignInServiceError.notSignedIn
                }
                let authorized = try await credentialIsAuthorized(subject)
                try Task.checkCancellation()
                guard authorized else {
                    try await Self.clearRevokedSession(client)
                    throw AppleSignInServiceError.notSignedIn
                }
                return session.user.id
            }
        } catch AuthError.sessionMissing {
            throw AppleSignInServiceError.notSignedIn
        }
    }

    private static func nativeCredentialIsAuthorized(_ subject: String) async throws -> Bool {
        let state: ASAuthorizationAppleIDProvider.CredentialState = try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: subject) { state, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: state) }
            }
        }
        return state == .authorized
    }

    private static func clearRevokedSession(_ client: SupabaseClient) async throws {
        do { try await clearSession(client) }
        catch {
            guard client.auth.currentSession == nil else { throw AppleSignInServiceError.sessionNotCleared }
            Logger(subsystem: "com.farrierflow.yusufcan.FarrierFlow", category: "BackupSync")
                .notice("Revoked Apple authorization cleared locally; remote logout was not confirmed.")
        }
    }

    func signOut() async throws {
        // SDK removes the local Keychain session before its network request.
        // A failed logout must still be surfaced; other phones stay signed in.
        try await operations.run { [client] in try await Self.clearSession(client) }
    }

    private static func clearSession(_ client: SupabaseClient) async throws {
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            guard client.auth.currentSession == nil else { throw AppleSignInServiceError.sessionNotCleared }
            throw error
        }
        guard client.auth.currentSession == nil else { throw AppleSignInServiceError.sessionNotCleared }
    }
}

/// Explicit account commands cannot overtake an earlier exchange and clear
/// a newer user's session. Token refresh is independently fenced by the SDK.
private actor AppleSessionOperations {
    private var active = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run<Result: Sendable>(_ operation: @Sendable () async throws -> Result) async throws -> Result {
        if active {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            active = true
        }
        defer {
            if waiters.isEmpty { active = false }
            else { waiters.removeFirst().resume() }
        }
        return try await operation()
    }
}
