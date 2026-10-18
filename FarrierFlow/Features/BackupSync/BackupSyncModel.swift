import AuthenticationServices
import Foundation
import Observation
import Supabase
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BackupSyncModel {
    private(set) var session: CloudAccountSession?
    private(set) var runtime: BackupSyncRuntime?
    private(set) var deletion: CloudDeletionController?
    let deletionAvailable: Bool
    private(set) var authenticationObservationID = UUID()
    @ObservationIgnored private var client: SupabaseClient?
    @ObservationIgnored private var factory: (@MainActor () throws -> BackupSyncComponents)?
    @ObservationIgnored private var preferences: UserDefaults?
    @ObservationIgnored private var challenge: AppleSignInChallenge?
    @ObservationIgnored private var deletionPrompt = false
    private(set) var isRequestingApple = false
    private(set) var hasCheckedStoredSession = false
    var alert: FeatureAlert?

    var isAvailable: Bool { session != nil || factory != nil }
    var isBusy: Bool { isRequestingApple || session?.isBusy == true || deletion?.isBusy == true }
    var accountState: CloudAccountSessionState { session?.state ?? .localOnly }
    var protectionStatus: SyncProtectionStatus? { runtime?.status }
    var shouldOfferInvitation: Bool {
        guard hasCheckedStoredSession, isAvailable, !isBusy, accountState == .localOnly,
              deletion?.isFenced != true,
              let preferences else { return false }
        return !CloudAccountSession.prefersLocalOnly(in: preferences) &&
            !preferences.bool(forKey: "backupSync.invitationSeen")
    }

    init(session: CloudAccountSession? = nil, runtime: BackupSyncRuntime? = nil,
         client: SupabaseClient? = nil, preferences: UserDefaults? = nil,
         deletion: CloudDeletionController? = nil, deletionAvailable: Bool = false) {
        self.session = session
        self.runtime = runtime
        self.client = client
        self.preferences = preferences
        self.deletion = deletion
        self.deletionAvailable = deletionAvailable
    }

    func prepareCloudDeletion() -> AppleSignInChallenge? {
        guard deletionAvailable, !isBusy, let deletion,
              let account = deletion.intent?.accountID ?? session?.accountID,
              accountState == .connected || deletion.intent?.phase == .sent || deletion.intent?.phase == .prepared,
              ensureComponents() else { return nil }
        do {
            let value = try deletion.prepare(accountID: account)
            challenge = value
            deletionPrompt = true
            isRequestingApple = true
            alert = nil
            return value
        } catch { cloudDeletionFailed(); return nil }
    }

    func completeCloudDeletion(identityToken: Data, authorizationCode: Data) async {
        guard deletionPrompt, isRequestingApple, let deletion, let challenge,
              let intent = deletion.intent, let session else { cloudDeletionFailed(); return }
        deletionPrompt = false
        self.challenge = nil
        isRequestingApple = false
        do {
            try await session.authenticateForDeletion(identityToken: identityToken, challenge: challenge,
                expectedAccountID: intent.accountID)
        } catch {
            do { try deletion.cancelAuthorization() }
            catch { cloudDeletionFailed() }
            cloudDeletionFailed()
            return
        }
        await deletion.submit(identityToken: identityToken, authorizationCode: authorizationCode)
        if deletion.state == .pending || deletion.state == .complete { await signOut() }
    }

    func cancelCloudDeletion() async {
        deletionPrompt = false
        challenge = nil
        isRequestingApple = false
        do {
            try deletion?.cancelAuthorization()
            if deletion?.isFenced != true { await restore() }
        } catch { cloudDeletionFailed() }
    }

    func cloudDeletionFailed() {
        deletionPrompt = false
        challenge = nil
        isRequestingApple = false
        alert = FeatureAlert(title: BackupSyncCopy.deletionFailureTitle, message: BackupSyncCopy.deletionFailure)
    }

    func refreshCloudDeletion() async {
        guard !isRequestingApple else { return }
        await deletion?.resume()
        if deletion?.state == .pending || deletion?.state == .complete { await signOut() }
    }

    static func configured(container: ModelContainer, library: PhotographLibrary,
                           preferences: UserDefaults) -> BackupSyncModel {
        do {
            let config = try SupabaseConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
            let model = BackupSyncModel(deletionAvailable: config.cloudDeletionIsAvailable(
                infoDictionary: Bundle.main.infoDictionary ?? [:]))
            model.preferences = preferences
            let confirmation = FunctionsClient(url: config.url.appending(path: "functions/v1"),
                headers: ["apikey": config.publishableKey])
            let deletionTransport = SupabaseCloudDeletionTransport(authenticated: { [weak model] in
                try await MainActor.run {
                    guard let client = model?.client else { throw AppleSignInServiceError.notSignedIn }
                    return client.functions
                }
            }, confirmation: confirmation)
            model.deletion = CloudDeletionController(container: container, receipts: CloudDeletionReceiptStore(),
                transport: deletionTransport, stopped: { [weak model] in model?.runtime?.stop() })
            model.factory = {
                let deviceID = try SyncDeviceIdentity.loadOrCreate()
                let client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.publishableKey,
                    options: .init(auth: .init(storage: SyncSessionKeychainStorage(),
                        autoRefreshToken: false, emitLocalSessionAsInitialSession: true)))
                let runtime = BackupSyncRuntime(container: container,
                    transport: SupabaseSyncTransport(client: client),
                    photoTransport: SupabasePhotoTransport(client: client), library: library, deviceID: deviceID)
                let session = CloudAccountSession(authentication: AppleSignInService(client: client),
                    preferences: preferences, connected: { [weak runtime] id in try runtime?.connect(accountID: id) },
                    stopped: { [weak runtime] in runtime?.stop() })
                return BackupSyncComponents(session: session, runtime: runtime, client: client)
            }
            return model
        } catch {
            // An unavailable cloud configuration/Keychain cannot prevent use
            // of the existing local business store or subscription features.
            return BackupSyncModel()
        }
    }

    func restore() async {
        defer { hasCheckedStoredSession = true }
        guard !isRequestingApple else { return }
        await deletion?.resume()
        guard deletion?.isFenced != true else { return }
        if let preferences, CloudAccountSession.prefersLocalOnly(in: preferences) { return }
        guard ensureComponents() else { return }
        await session?.restore()
    }

    func prepareAppleSignIn() -> AppleSignInChallenge? {
        guard isAvailable, !isBusy, deletion?.isFenced != true else { return nil }
        guard ensureComponents() else { return nil }
        alert = nil
        do {
            let value = try AppleSignInChallenge()
            challenge = value
            isRequestingApple = true
            return value
        } catch { nativeSignInFailed(); return nil }
    }

    func completeAppleSignIn(identityToken: Data) async {
        guard !deletionPrompt, let challenge, let session else { nativeSignInFailed(); return }
        self.challenge = nil
        isRequestingApple = false
        await session.signIn(identityToken: identityToken, challenge: challenge)
    }

    func cancelAppleSignIn() { challenge = nil; isRequestingApple = false; deletionPrompt = false }

    func nativeSignInFailed() {
        cancelAppleSignIn()
        alert = FeatureAlert(title: LocalizedStringResource("backupSync.signInFailure.title", defaultValue: "Couldn’t Sign In"),
            message: LocalizedStringResource("backupSync.signInFailure.message", defaultValue: "Your records are still on this iPhone. Try signing in again when you have an internet connection."))
    }

    func signOut() async {
        cancelAppleSignIn()
        await session?.signOut()
        await runtime?.waitUntilIdle()
    }

    func continueLocally() async {
        cancelAppleSignIn()
        if let preferences { CloudAccountSession.chooseLocalOnly(in: preferences) }
        if session != nil { await signOut() }
    }

    func consumeInvitation() -> Bool {
        guard shouldOfferInvitation, let preferences else { return false }
        preferences.set(true, forKey: "backupSync.invitationSeen")
        return true
    }

    func retry() async {
        guard !isBusy else { return }
        if deletion?.isFenced == true { await refreshCloudDeletion(); return }
        if accountState == .connected { runtime?.requestSync() }
        else { await restore() }
    }

    func prepareInvoiceRecovery() async throws -> SyncInvoiceRecoveryModel {
        guard deletion?.isFenced != true, accountState == .connected, let runtime else {
            throw SyncJournalError.accountMismatch
        }
        return try await runtime.prepareRecovery(currentAccount: { [weak self] in
            guard self?.accountState == .connected, self?.deletion?.isFenced != true else { return nil }
            return self?.session?.accountID
        })
    }

    func connectionBecameAvailable() async {
        guard !isRequestingApple else { return }
        if deletion?.isFenced == true { await refreshCloudDeletion(); return }
        if accountState == .connected { runtime?.requestSync() }
        else if accountState == .waitingForConnection { await restore() }
    }

    func observeAuthentication() async {
        guard let client else { return }
        for await (event, value) in client.auth.authStateChanges {
            guard !Task.isCancelled else { return }
            if event == .signedOut { session?.sessionWasInvalidated() }
            else if let expected = session?.accountID, let value, expected != value.user.id {
                await signOut()
            }
        }
    }

    private func ensureComponents() -> Bool {
        if session != nil { return true }
        guard let factory else { return false }
        do {
            let components = try factory()
            session = components.session
            runtime = components.runtime
            client = components.client
            self.factory = nil
            authenticationObservationID = UUID()
            return true
        } catch {
            nativeSignInFailed()
            return false
        }
    }

    func observeWorkspace() async {
        guard deletion?.isFenced != true, let client, let runtime, accountState == .connected,
              let account = session?.accountID, let workspace = runtime.workspaceID else { return }
        let channel = client.channel("ff-workspace:" + workspace.uuidString.lowercased()) { $0.isPrivate = true }
        let events = channel.broadcastStream(event: "changed")
        let statuses = channel.statusChange
        let rejoined = Task { [weak self] in
            for await status in statuses {
                guard !Task.isCancelled, let self,
                      self.session?.accountID == account, self.runtime?.workspaceID == workspace else { return }
                // Rejoining can miss broadcasts; fetch the authorized cursor
                // regardless of the payload or advertised revision.
                if status == .subscribed { self.runtime?.requestSync() }
            }
        }
        do {
            try await channel.subscribeWithError()
            for await _ in events {
                try Task.checkCancellation()
                guard session?.accountID == account, runtime.workspaceID == workspace else { break }
                runtime.requestSync()
            }
        } catch {
            // Realtime is a hint, not durability. Foreground/reconnect/retry
            // still refetch the journal; never mark records protected here.
        }
        rejoined.cancel()
        await client.removeChannel(channel)
        await rejoined.value
    }
}

@MainActor
private struct BackupSyncComponents {
    let session: CloudAccountSession
    let runtime: BackupSyncRuntime
    let client: SupabaseClient
}

extension EnvironmentValues {
    @Entry var backupSync: BackupSyncModel? = nil
}
