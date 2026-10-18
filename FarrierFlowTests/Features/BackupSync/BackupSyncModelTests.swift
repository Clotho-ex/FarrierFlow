import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Native backup account surface", .serialized)
@MainActor
struct BackupSyncModelTests {
    @Test
    func unavailableConfigurationDoesNotPreventAccountFreeUse() async {
        let model = BackupSyncModel()
        await model.restore()
        #expect(!model.isAvailable)
        #expect(model.accountState == .localOnly)
        #expect(model.protectionStatus == nil)
    }

    @Test
    func nativeChallengeIsConsumedOnceAndNeverAcceptsAnUnsolicitedToken() async throws {
        let auth = SurfaceAuthentication()
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let session = CloudAccountSession(authentication: auth, preferences: preferences,
            connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session)
        await model.completeAppleSignIn(identityToken: Data("unsolicited".utf8))
        #expect(await auth.exchangeCount == 0)
        #expect(model.alert != nil)
        let challenge = try #require(model.prepareAppleSignIn())
        await model.completeAppleSignIn(identityToken: Data("native-token".utf8))
        #expect(await auth.nonce == challenge.rawNonce)
        #expect(model.accountState == .connected)
        #expect(model.protectionStatus == nil)
        await model.completeAppleSignIn(identityToken: Data("replayed".utf8))
        #expect(await auth.exchangeCount == 1)
    }

    @Test
    func cancellingNativePromptDoesNotAuthenticateOrPresentAnError() async throws {
        let auth = SurfaceAuthentication()
        let session = CloudAccountSession(authentication: auth, preferences: .standard,
            connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session)
        _ = try #require(model.prepareAppleSignIn())
        model.cancelAppleSignIn()
        #expect(!model.isBusy)
        #expect(model.alert == nil)
        #expect(await auth.exchangeCount == 0)
    }

    @Test
    func reconnectCannotUndoAnExplicitSignOut() async throws {
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let auth = SurfaceAuthentication()
        let session = CloudAccountSession(authentication: auth, preferences: preferences,
            connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session)
        await model.restore()
        await model.signOut()
        let count = await auth.restoreCount
        await model.connectionBecameAvailable()
        #expect(await auth.restoreCount == count)
        #expect(model.accountState == .localOnly)
    }

    @Test
    func signedOutRelaunchDoesNotConstructSDKOrReadADeviceIdentity() async throws {
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        preferences.set(true, forKey: "backupSync.explicitlySignedOut")
        let container = try ModelContainerFactory.inMemoryTest()
        let root = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Signed-Out-")
        let library = PhotographLibrary(container: container,
            fileStore: PhotographFileStore(rootURL: root.appending(path: "HoofPhotographs")))
        let model = BackupSyncModel.configured(container: container, library: library, preferences: preferences)
        #expect(model.isAvailable)
        await model.restore()
        #expect(model.session == nil)
        #expect(model.runtime == nil)
        #expect(model.accountState == .localOnly)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()) == 0)
    }

    @Test
    func foregroundRestoreCannotConsumeAnOpenNativeChallenge() async throws {
        let auth = SurfaceAuthentication()
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let session = CloudAccountSession(authentication: auth, preferences: preferences,
            connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session)
        _ = try #require(model.prepareAppleSignIn())
        await model.restore()
        #expect(await auth.restoreCount == 0)
        #expect(model.isRequestingApple)
        await model.completeAppleSignIn(identityToken: Data("native-token".utf8))
        #expect(model.accountState == .connected)
    }

    @Test
    func decliningInvitationIsRememberedAndDoesNotConstructCloudServices() async throws {
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let container = try ModelContainerFactory.inMemoryTest()
        let root = try TemporaryStoreFixtures.makeDirectory(prefix: "Sync-Decline-")
        let library = PhotographLibrary(container: container,
            fileStore: PhotographFileStore(rootURL: root.appending(path: "HoofPhotographs")))
        let model = BackupSyncModel.configured(container: container, library: library, preferences: preferences)
        await model.continueLocally()
        await model.restore()
        #expect(model.session == nil)
        #expect(model.runtime == nil)
        #expect(CloudAccountSession.prefersLocalOnly(in: preferences))
        #expect(!model.shouldOfferInvitation)
    }

    @Test
    func invitationIsOfferedOnceOnlyAfterStoredSessionWasChecked() async throws {
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let auth = SurfaceAuthentication(noAccount: true)
        let session = CloudAccountSession(authentication: auth, preferences: preferences,
            connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session, preferences: preferences)
        #expect(!model.shouldOfferInvitation)
        await model.restore()
        #expect(model.shouldOfferInvitation)
        #expect(model.consumeInvitation())
        #expect(!model.consumeInvitation())
        let reopened = BackupSyncModel(session: session, preferences: preferences)
        await reopened.restore()
        #expect(!reopened.shouldOfferInvitation)
    }
}

private actor SurfaceAuthentication: CloudAccountAuthentication {
    let id = UUID()
    private(set) var exchangeCount = 0
    private(set) var restoreCount = 0
    private(set) var nonce: String?
    private let noAccount: Bool
    init(noAccount: Bool = false) { self.noAccount = noAccount }
    func currentAccountID() async throws -> UUID {
        restoreCount += 1
        if noAccount { throw AppleSignInServiceError.notSignedIn }
        return id
    }
    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async throws -> UUID {
        exchangeCount += 1
        nonce = challenge.rawNonce
        return id
    }
    func signOut() async throws {}
}
