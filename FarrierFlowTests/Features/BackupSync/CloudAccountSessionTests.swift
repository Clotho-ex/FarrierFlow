import Foundation
import Testing
@testable import FarrierFlow

@Suite("Optional cloud account lifecycle", .serialized)
@MainActor
struct CloudAccountSessionTests {
    @Test
    func validSessionActivatesOnlyAfterBindingValidation() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let events = SessionEvents()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { events.connected.append($0) }, stopped: { events.didStop() })
        await model.restore()
        #expect(model.accountID == fixture.auth.id)
        #expect(events.connected == [fixture.auth.id])
        #expect(model.state == .connected)
    }

    @Test
    func bindingMismatchCannotActivateCloudWork() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let events = SessionEvents()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { _ in throw SyncJournalError.accountMismatch }, stopped: { events.didStop() })
        await model.restore()
        #expect(model.accountID == nil)
        #expect(model.state == .needsMatchingAccount)
        #expect(events.connected.isEmpty)
    }

    @Test
    func refreshFailureStopsPreviouslyActivatedSync() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let events = SessionEvents()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { events.connected.append($0) }, stopped: { events.didStop() })
        await model.restore()
        await fixture.auth.failRestore()
        let stoppedBefore = events.stopped
        await model.restore()
        #expect(model.accountID == nil)
        #expect(events.stopped > stoppedBefore)
        #expect(model.state == .waitingForConnection)
    }

    @Test
    func signOutChoiceSurvivesModelRecreationAndDoesNotAutoRestore() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
                                       connected: { _ in }, stopped: {})
        await model.restore()
        await model.signOut()
        let before = await fixture.auth.restoreCount
        let reopened = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
                                          connected: { _ in }, stopped: {})
        await reopened.restore()
        #expect(reopened.accountID == nil)
        #expect(reopened.state == .localOnly)
        #expect(await fixture.auth.restoreCount == before)
    }

    @Test
    func signOutStopsWorkBeforeNetworkAndRejectsLateSignInCompletion() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let events = SessionEvents()
        await fixture.auth.pauseSignIn()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { events.connected.append($0) }, stopped: { events.didStop() })
        let signIn = Task { await model.signIn(identityToken: Data("synthetic".utf8), challenge: try AppleSignInChallenge()) }
        await fixture.auth.waitForSignIn()
        let stoppedBefore = events.stopped
        let signOut = Task { await model.signOut() }
        await events.waitForStopped(after: stoppedBefore)
        #expect(model.accountID == nil)
        #expect(events.stopped > 0)
        await fixture.auth.resumeSignIn()
        try await signIn.value
        await signOut.value
        #expect(model.accountID == nil)
        #expect(model.state == .localOnly)
        #expect(events.connected.isEmpty)
    }

    @Test
    func invalidatedAccountCannotBeReactivatedByPendingAuthentication() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let events = SessionEvents()
        await fixture.auth.pauseSignIn()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { events.connected.append($0) }, stopped: { events.didStop() })
        let signIn = Task { await model.signIn(identityToken: Data("synthetic".utf8), challenge: try AppleSignInChallenge()) }
        await fixture.auth.waitForSignIn()
        model.sessionWasInvalidated()
        await fixture.auth.resumeSignIn()
        try await signIn.value
        #expect(model.accountID == nil)
        #expect(model.state == .localOnly)
        #expect(events.connected.isEmpty)
    }

    @Test
    func offlineSignOutStopsCloudAndPreservesChoiceWithoutClaimingServerRevocation() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let events = SessionEvents()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { events.connected.append($0) }, stopped: { events.didStop() })
        await model.restore()
        await fixture.auth.failSignOut()
        await model.signOut()
        #expect(model.accountID == nil)
        #expect(model.state == .signedOutWithUnconfirmedRevocation)
        let count = await fixture.auth.restoreCount
        await model.restore()
        #expect(await fixture.auth.restoreCount == count)
    }

    @Test
    func accountFreeLaunchDoesNotDisplayAnAuthenticationFailure() async throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        await fixture.auth.removeSavedSession()
        let events = SessionEvents()
        let model = CloudAccountSession(authentication: fixture.auth, preferences: fixture.defaults,
            connected: { events.connected.append($0) }, stopped: { events.didStop() })
        await model.restore()
        #expect(model.state == .localOnly)
        #expect(model.accountID == nil)
        #expect(events.connected.isEmpty)
    }

    private func makeFixture() throws -> (auth: SessionAuthentication, defaults: UserDefaults, name: String) {
        let name = "FarrierFlow.CloudSession.Tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        return (SessionAuthentication(), defaults, name)
    }

    private final class SessionEvents {
        var connected: [UUID] = []
        var stopped = 0
        private var waiter: CheckedContinuation<Void, Never>?
        func didStop() { stopped += 1; waiter?.resume(); waiter = nil }
        func waitForStopped(after count: Int) async {
            if stopped > count { return }
            await withCheckedContinuation { waiter = $0 }
        }
    }
}

private actor SessionAuthentication: CloudAccountAuthentication {
    let id = UUID()
    private(set) var restoreCount = 0
    private var offline = false
    private var offlineSignOut = false
    private var noSession = false
    private var pause = false
    private var signInContinuation: CheckedContinuation<Void, Never>?
    private var signInWaiter: CheckedContinuation<Void, Never>?
    private var signOutRequested = false
    private var signOutWaiter: CheckedContinuation<Void, Never>?

    func currentAccountID() async throws -> UUID {
        restoreCount += 1
        if noSession { throw AppleSignInServiceError.notSignedIn }
        if offline { throw URLError(.notConnectedToInternet) }
        return id
    }
    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async throws -> UUID {
        if pause {
            await withCheckedContinuation {
                signInContinuation = $0
                signInWaiter?.resume()
                signInWaiter = nil
            }
        }
        return id
    }
    func signOut() async throws {
        signOutRequested = true
        signOutWaiter?.resume()
        signOutWaiter = nil
        if offlineSignOut { throw URLError(.notConnectedToInternet) }
    }
    func failRestore() { offline = true }
    func failSignOut() { offlineSignOut = true }
    func removeSavedSession() { noSession = true }
    func pauseSignIn() { pause = true }
    func waitForSignIn() async {
        if signInContinuation != nil { return }
        await withCheckedContinuation { signInWaiter = $0 }
    }
    func waitForSignOutRequest() async {
        if signOutRequested { return }
        await withCheckedContinuation { signOutWaiter = $0 }
    }
    func resumeSignIn() { signInContinuation?.resume(); signInContinuation = nil }
}
