import Foundation
import Observation
import Synchronization

nonisolated protocol CloudAccountAuthentication: Sendable {
    func currentAccountID() async throws -> UUID
    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async throws -> UUID
    func signOut() async throws
}

nonisolated enum CloudAccountSessionState: Equatable, Sendable {
    case localOnly, working, connected, waitingForConnection, needsMatchingAccount, failed
    case signedOutWithUnconfirmedRevocation
}

@MainActor
@Observable
final class CloudAccountSession {
    private let authentication: any CloudAccountAuthentication
    private let preferences: UserDefaults
    private let connected: @MainActor (UUID) throws -> Void
    private let stopped: @MainActor () -> Void
    private nonisolated let request = Mutex<Task<UUID, Error>?>(nil)
    @ObservationIgnored private var epoch = UUID()
    @ObservationIgnored private var isSigningOut = false
    private static let localOnlyPreference = "backupSync.explicitlySignedOut"

    static func prefersLocalOnly(in preferences: UserDefaults) -> Bool {
        preferences.bool(forKey: localOnlyPreference)
    }

    static func chooseLocalOnly(in preferences: UserDefaults) {
        preferences.set(true, forKey: localOnlyPreference)
    }

    private(set) var accountID: UUID?
    private(set) var state: CloudAccountSessionState = .localOnly
    var isBusy: Bool { state == .working }

    init(authentication: any CloudAccountAuthentication, preferences: UserDefaults,
         connected: @escaping @MainActor (UUID) throws -> Void,
         stopped: @escaping @MainActor () -> Void) {
        self.authentication = authentication
        self.preferences = preferences
        self.connected = connected
        self.stopped = stopped
    }

    func restore() async {
        guard !isBusy else { return }
        guard !preferences.bool(forKey: Self.localOnlyPreference) else {
            accountID = nil
            stopped()
            state = .localOnly
            return
        }
        let generation = begin()
        let authentication = authentication
        let task = Task { try await authentication.currentAccountID() }
        request.withLock { $0 = task }
        await complete(task, generation: generation)
    }

    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async {
        guard !isBusy else { return }
        let generation = begin()
        let authentication = authentication
        let task = Task { try await authentication.signIn(identityToken: identityToken, challenge: challenge) }
        request.withLock { $0 = task }
        await complete(task, generation: generation)
    }

    func authenticateForDeletion(identityToken: Data, challenge: AppleSignInChallenge,
                                 expectedAccountID: UUID) async throws {
        guard !isBusy else { throw CloudDeletionError.invalidPhase }
        let generation = begin()
        let authentication = authentication
        let task = Task { try await authentication.signIn(identityToken: identityToken, challenge: challenge) }
        request.withLock { $0 = task }
        defer {
            if epoch == generation {
                request.withLock { $0 = nil }
                accountID = nil
                state = .localOnly
            }
        }
        let id = try await task.value
        guard epoch == generation else { throw CancellationError() }
        try Task.checkCancellation()
        guard id == expectedAccountID else {
            await signOut()
            throw SyncJournalError.accountMismatch
        }
        // Only refresh credentials for the fenced deletion request. Never
        // activate sync or undo the user's local-only preference here.
    }

    func signOut() async {
        let pending = request.withLock { value in
            let old = value
            value = nil
            return old
        }
        epoch = UUID()
        let generation = epoch
        isSigningOut = true
        defer { if epoch == generation { isSigningOut = false } }
        accountID = nil
        stopped()
        preferences.set(true, forKey: Self.localOnlyPreference)
        state = .working
        pending?.cancel()
        // Complete cleanup of an earlier exchange before clearing the session.
        // This also protects against authentication adapters ignoring cancellation.
        if let pending { _ = await pending.result }
        do {
            try await authentication.signOut()
            guard epoch == generation else { return }
            state = .localOnly
        } catch {
            guard epoch == generation else { return }
            state = .signedOutWithUnconfirmedRevocation
        }
    }

    func sessionWasInvalidated() {
        accountID = nil
        stopped()
        // SDK sign-out notifications do not replace the explicit operation's
        // final result, especially if network revocation cannot be confirmed.
        guard !isSigningOut else { return }
        epoch = UUID()
        request.withLock { $0?.cancel(); $0 = nil }
        preferences.set(true, forKey: Self.localOnlyPreference)
        state = .localOnly
    }

    private func begin() -> UUID {
        epoch = UUID()
        accountID = nil
        stopped()
        state = .working
        return epoch
    }

    private func complete(_ task: Task<UUID, Error>, generation: UUID) async {
        defer {
            if epoch == generation { request.withLock { $0 = nil } }
        }
        do {
            let id = try await task.value
            guard epoch == generation else { return }
            try Task.checkCancellation()
            try connected(id)
            accountID = id
            preferences.set(false, forKey: Self.localOnlyPreference)
            state = .connected
        } catch {
            guard epoch == generation else { return }
            accountID = nil
            stopped()
            if error is CancellationError || error as? AppleSignInServiceError == .notSignedIn { state = .localOnly }
            else if error as? SyncJournalError == .accountMismatch { state = .needsMatchingAccount }
            else if error is URLError { state = .waitingForConnection }
            else { state = .failed }
        }
    }

    deinit {
        request.withLock { $0?.cancel(); $0 = nil }
    }
}
