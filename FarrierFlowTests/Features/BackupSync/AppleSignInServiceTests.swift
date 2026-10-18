import Foundation
import Supabase
import Synchronization
import Testing
@testable import FarrierFlow

@Suite("Apple account exchange", .serialized)
struct AppleSignInServiceTests {
    @Test
    func exchangesAppleIdentityWithRawNonceAndPersistsOfficialSDKSession() async throws {
        let account = UUID()
        let challenge = try AppleSignInChallenge(randomData: { Data(repeating: 7, count: $0) })
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/auth/v1/token")
            #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?.contains(.init(name: "grant_type", value: "id_token")) == true)
            let credentials = try JSONDecoder().decode(
                Credentials.self, from: SyncHTTPStub.body(of: request)
            )
            #expect(credentials.provider == "apple")
            #expect(credentials.id_token == "apple-test-token")
            #expect(credentials.nonce == challenge.rawNonce)
            return (200, Self.sessionResponse(account: account))
        }
        defer { SyncHTTPStub.configure(nil) }
        let storage = SyncTestAuthStorage()
        let service = AppleSignInService(client: try makeClient(storage: storage))
        let result = try await service.signIn(
            identityToken: Data("apple-test-token".utf8), challenge: challenge
        )
        #expect(result == account)
        let reopened = AppleSignInService(client: try makeClient(storage: storage), credentialIsAuthorized: { subject in
            #expect(subject == "synthetic-apple-subject")
            return true
        })
        let restored = try await reopened.currentAccountID()
        #expect(restored == account)
    }

    @Test(arguments: [Data(), Data([0xff, 0xfe])])
    func refusesMissingOrNonUTF8AppleIdentityBeforeAnyNetworkRequest(token: Data) async throws {
        let service = AppleSignInService(client: try makeClient(storage: SyncTestAuthStorage()))
        let challenge = try AppleSignInChallenge()
        await #expect(throws: AppleSignInServiceError.invalidIdentityToken) {
            try await service.signIn(identityToken: token, challenge: challenge)
        }
    }

    @Test
    func signOutIsLocalToThisPhoneAndClearsSessionEvenWhenOffline() async throws {
        let account = UUID()
        SyncHTTPStub.configure { request in
            if request.url?.path == "/auth/v1/token" {
                return (200, Self.sessionResponse(account: account))
            }
            #expect(request.url?.path == "/auth/v1/logout")
            #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?.contains(.init(name: "scope", value: "local")) == true)
            throw URLError(.notConnectedToInternet)
        }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: SyncTestAuthStorage())
        let service = AppleSignInService(client: client)
        _ = try await service.signIn(
            identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge()
        )
        await #expect(throws: (any Error).self) { try await service.signOut() }
        #expect(client.auth.currentSession == nil)
    }

    @Test
    func failedKeychainWriteCannotBeReportedAsSuccessfulSignIn() async throws {
        let account = UUID()
        SyncHTTPStub.configure { _ in (200, Self.sessionResponse(account: account)) }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: FailingStorage(failStore: true, failRemove: false))
        let service = AppleSignInService(client: client)
        await #expect(throws: AppleSignInServiceError.sessionNotStored) {
            try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        }
        #expect(client.auth.currentSession == nil)
    }

    @Test
    func failedKeychainRemovalCannotBeReportedAsSuccessfulSignOut() async throws {
        let account = UUID()
        SyncHTTPStub.configure { request in
            request.url?.path == "/auth/v1/token" ? (200, Self.sessionResponse(account: account)) : (200, Data())
        }
        defer { SyncHTTPStub.configure(nil) }
        let service = AppleSignInService(client: try makeClient(storage: FailingStorage(failStore: false, failRemove: true)))
        _ = try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        await #expect(throws: AppleSignInServiceError.sessionNotCleared) { try await service.signOut() }
    }

    @Test
    func officialSDKSessionReopensThroughDeviceBoundKeychainStorage() async throws {
        let account = UUID()
        let storage = SyncSessionKeychainStorage(service: "FarrierFlow.Auth.Exchange.Tests." + UUID().uuidString)
        let storageKey = "sb-apple-test-auth-token"
        defer { try? storage.remove(key: storageKey) }
        SyncHTTPStub.configure { _ in (200, Self.sessionResponse(account: account)) }
        defer { SyncHTTPStub.configure(nil) }
        let first = AppleSignInService(client: try makeClient(storage: storage))
        _ = try await first.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        let reopened = AppleSignInService(client: try makeClient(storage: storage), credentialIsAuthorized: { _ in true })
        let restored = try await reopened.currentAccountID()
        #expect(restored == account)
        #expect(try storage.retrieve(key: storageKey) != nil)
    }

    @Test
    func cancelledExchangeCannotLeaveAnAutoRestorableSession() async throws {
        let account = UUID()
        let storage = PausedStorage()
        defer { storage.resume() }
        SyncHTTPStub.configure { request in
            request.url?.path == "/auth/v1/token" ? (200, Self.sessionResponse(account: account)) : (200, Data())
        }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: storage)
        let service = AppleSignInService(client: client)
        let task = Task {
            try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        }
        await storage.started.wait()
        task.cancel()
        storage.resume()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(client.auth.currentSession == nil)
    }

    @Test
    func noSavedSessionIsExplicitlyAccountFreeNotARefreshFailure() async throws {
        let service = AppleSignInService(client: try makeClient(storage: SyncTestAuthStorage()))
        await #expect(throws: AppleSignInServiceError.notSignedIn) { try await service.currentAccountID() }
    }

    @Test
    func revokedNativeAppleAuthorizationCannotRestoreACachedSupabaseSession() async throws {
        let account = UUID()
        SyncHTTPStub.configure { request in
            request.url?.path == "/auth/v1/token" ? (200, Self.sessionResponse(account: account)) : (200, Data())
        }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: SyncTestAuthStorage())
        let service = AppleSignInService(client: client, credentialIsAuthorized: { subject in
            #expect(subject == "synthetic-apple-subject")
            return false
        })
        _ = try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        await #expect(throws: AppleSignInServiceError.notSignedIn) { try await service.currentAccountID() }
        #expect(client.auth.currentSession == nil)
    }

    @Test
    func nativeCredentialCheckFailureDoesNotAuthorizeCloudAndKeepsSessionAvailableForRetry() async throws {
        let account = UUID()
        SyncHTTPStub.configure { _ in (200, Self.sessionResponse(account: account)) }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: SyncTestAuthStorage())
        let service = AppleSignInService(client: client, credentialIsAuthorized: { _ in
            throw URLError(.notConnectedToInternet)
        })
        _ = try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        await #expect(throws: URLError.self) { try await service.currentAccountID() }
        #expect(client.auth.currentSession?.user.id == account)
    }

    @Test
    func userMetadataCannotSubstituteForAServerLinkedAppleIdentity() async throws {
        let account = UUID()
        SyncHTTPStub.configure { request in
            request.url?.path == "/auth/v1/token" ?
                (200, Self.sessionResponse(account: account, identityProvider: "email")) : (200, Data())
        }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: SyncTestAuthStorage())
        let service = AppleSignInService(client: client, credentialIsAuthorized: { _ in true })
        _ = try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        await #expect(throws: AppleSignInServiceError.notSignedIn) { try await service.currentAccountID() }
        #expect(client.auth.currentSession == nil)
    }

    @Test
    func revokedAuthorizationIsClearedLocallyEvenWhenRemoteLogoutIsOffline() async throws {
        let account = UUID()
        SyncHTTPStub.configure { request in
            if request.url?.path == "/auth/v1/token" { return (200, Self.sessionResponse(account: account)) }
            throw URLError(.notConnectedToInternet)
        }
        defer { SyncHTTPStub.configure(nil) }
        let client = try makeClient(storage: SyncTestAuthStorage())
        let service = AppleSignInService(client: client, credentialIsAuthorized: { _ in false })
        _ = try await service.signIn(identityToken: Data("apple-test-token".utf8), challenge: AppleSignInChallenge())
        await #expect(throws: AppleSignInServiceError.notSignedIn) { try await service.currentAccountID() }
        #expect(client.auth.currentSession == nil)
    }

    private func makeClient(storage: any AuthLocalStorage) throws -> SupabaseClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncHTTPStub.self]
        return SupabaseClient(
            supabaseURL: try #require(URL(string: "https://apple-test.supabase.co")),
            supabaseKey: "sb_publishable_test_only",
            options: .init(
                auth: .init(storage: storage, autoRefreshToken: false),
                global: .init(session: URLSession(configuration: configuration))
            )
        )
    }

    private nonisolated static func sessionResponse(account: UUID, identityProvider: String = "apple") -> Data {
        Data("""
        {"access_token":"test-session-token","token_type":"bearer","expires_in":3600,
         "expires_at":2524608000,"refresh_token":"test-refresh-token",
         "user":{"id":"\(account)","aud":"authenticated","app_metadata":{},
         "user_metadata":{"sub":"synthetic-apple-subject"},"created_at":"2026-10-13T00:00:00Z",
         "updated_at":"2026-10-13T00:00:00Z","is_anonymous":false,
         "identities":[{"id":"synthetic-apple-subject","identity_id":"00000000-0000-4000-8000-000000000001",
           "user_id":"\(account)","provider":"\(identityProvider)","identity_data":{"sub":"synthetic-apple-subject"}}]}}
        """.utf8)
    }

    private nonisolated struct Credentials: Decodable {
        let provider: String
        let id_token: String
        let nonce: String
    }

    private nonisolated struct FailingStorage: AuthLocalStorage {
        let failStore: Bool
        let failRemove: Bool
        private let memory = SyncTestAuthStorage()
        func store(key: String, value: Data) throws {
            if failStore { throw ForcedFailure.expected }
            try memory.store(key: key, value: value)
        }
        func retrieve(key: String) throws -> Data? { try memory.retrieve(key: key) }
        func remove(key: String) throws {
            if failRemove { throw ForcedFailure.expected }
            try memory.remove(key: key)
        }
        private enum ForcedFailure: Error { case expected }
    }

    private nonisolated final class PausedStorage: AuthLocalStorage {
        let started = StorageStarted()
        private let memory = SyncTestAuthStorage()
        private let pause = Mutex(true)
        private let permit = DispatchSemaphore(value: 0)
        func store(key: String, value: Data) throws {
            let shouldPause = pause.withLock { value in
                let old = value
                value = false
                return old
            }
            if shouldPause {
                Task { await started.signal() }
                guard permit.wait(timeout: .now() + 5) == .success else { throw PauseFailure.timeout }
            }
            try memory.store(key: key, value: value)
        }
        func retrieve(key: String) throws -> Data? { try memory.retrieve(key: key) }
        func remove(key: String) throws { try memory.remove(key: key) }
        func resume() { permit.signal() }
        private enum PauseFailure: Error { case timeout }
    }

    private actor StorageStarted {
        private var hasStarted = false
        private var waiter: CheckedContinuation<Void, Never>?
        func signal() { hasStarted = true; waiter?.resume(); waiter = nil }
        func wait() async {
            if hasStarted { return }
            await withCheckedContinuation { waiter = $0 }
        }
    }
}
