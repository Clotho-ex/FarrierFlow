import Foundation
import SwiftData
import Supabase
import Testing
@testable import FarrierFlow

@Suite("Retained business after confirmed cloud deletion", .serialized)
@MainActor
struct CloudDeletionControllerTests {
    @Test
    func preparingAndCancellingBeforeSubmissionRetainsDataAndNeverCallsServer() async throws {
        let f = try fixture()
        _ = try f.controller.prepare(accountID: f.account)
        #expect(f.controller.isFenced)
        #expect(try f.receipts.load()?.phase == .prepared)
        try f.controller.cancelPrepared()
        #expect(!f.controller.isFenced)
        #expect(try f.receipts.load() == nil)
        #expect(await f.transport.requestCount == 0)
        #expect(try f.store.journal()?.accountID == f.account)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func queuedDeletionFencesReuploadButRetainsBusinessAndOnlyCompletionShowsComplete() async throws {
        let f = try fixture()
        _ = try f.controller.prepare(accountID: f.account)
        await f.controller.submit(identityToken: Data("fresh-token".utf8), authorizationCode: Data("fresh-code".utf8))
        #expect(f.controller.state == .pending)
        #expect(try f.receipts.load()?.phase == .queued)
        #expect(throws: SyncJournalStoreError.cloudAccountDeleted) { try f.store.stage() }
        #expect(throws: SyncJournalStoreError.cloudAccountDeleted) {
            try f.store.bind(accountID: UUID(), workspaceID: UUID(), deviceID: UUID())
        }
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
        await f.transport.setComplete()
        await f.controller.refresh()
        #expect(f.controller.state == .complete)
        #expect(try f.receipts.load() == nil)
        let reopened = CloudDeletionController(container: f.container, receipts: f.receipts, transport: f.transport, stopped: {})
        await reopened.resume()
        #expect(reopened.state == .complete && reopened.isFenced)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func completedReceiptDoesNotFenceANewEmptyStoreButAnAmbiguousReceiptDoes() async throws {
        let f = try fixture()
        let intent = try f.receipts.prepare(accountID: f.account, workspaceID: try #require(try f.store.journal()?.workspaceID))
        try f.store.recordCloudDeletion(intent, status: .complete(intent.operationID))
        try f.receipts.advance(intent, to: .complete)
        let fresh = try ModelContainerFactory.inMemoryTest()
        let controller = CloudDeletionController(container: fresh, receipts: f.receipts, transport: f.transport, stopped: {})
        await controller.resume()
        #expect(controller.state == .localOnly && !controller.isFenced)
        #expect(try f.receipts.load() == nil)
        #expect(throws: SyncJournalStoreError.cloudAccountDeleted) { try f.store.stage() }

        let ambiguous = try f.receipts.prepare(accountID: f.account, workspaceID: intent.workspaceID)
        try f.receipts.advance(ambiguous, to: .sent)
        await controller.resume()
        #expect(controller.state == .unconfirmed && controller.isFenced)
        #expect(try f.receipts.load()?.phase == .sent)
    }

    @Test(arguments: [CloudDeletionPhase.sent, .queued])
    func survivingReceiptCanConfirmCompletionAfterReinstallWithoutOldBusinessStore(phase: CloudDeletionPhase) async throws {
        let f = try fixture()
        _ = try f.controller.prepare(accountID: f.account)
        if phase == .sent { await f.transport.loseNextReceipt() }
        await f.controller.submit(identityToken: Data("token".utf8), authorizationCode: Data("code".utf8))
        #expect(try f.receipts.load()?.phase == phase)
        await f.transport.setComplete()
        let fresh = try ModelContainerFactory.inMemoryTest()
        let controller = CloudDeletionController(container: fresh, receipts: f.receipts, transport: f.transport, stopped: {})
        await controller.resume()
        #expect(try f.receipts.load() == nil)
        #expect(!controller.isFenced && controller.state == .localOnly)
        #expect(try ModelContext(fresh).fetchCount(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()) == 0)
        if phase == .queued {
            #expect(throws: SyncJournalStoreError.cloudAccountDeleted) { try f.store.stage() }
        } else {
            #expect(try f.store.journal()?.accountID == f.account)
        }
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func completionForAnotherReceiptCannotDeclareARestoredPendingBusinessComplete() async throws {
        let f = try fixture()
        let original = try CloudDeletionIntent(accountID: f.account, workspaceID: try #require(try f.store.journal()?.workspaceID))
        try f.store.recordCloudDeletion(original, status: .pending(original.operationID))
        let other = try f.receipts.prepare(accountID: UUID(), workspaceID: UUID())
        try f.receipts.advance(other, to: .sent)
        _ = try await f.transport.request(other, identityToken: Data("token".utf8),
            authorizationCode: Data("code".utf8), challenge: AppleSignInChallenge())
        await f.transport.setComplete()
        await f.controller.resume()
        #expect(f.controller.isFenced && f.controller.state == .unconfirmed)
        #expect(try f.store.retainedDeletion()?.operationID == original.operationID)
        #expect(try f.store.retainedDeletion()?.completed == false)
        #expect(try f.receipts.load() == nil)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func confirmingAnAmbiguousReceiptOnItsOriginalStorePermanentlyFencesThatBusiness() async throws {
        let f = try fixture()
        _ = try f.controller.prepare(accountID: f.account)
        await f.transport.loseNextReceipt()
        await f.controller.submit(identityToken: Data("token".utf8), authorizationCode: Data("code".utf8))
        #expect(try f.receipts.load()?.phase == .sent)
        await f.transport.setComplete()
        await f.controller.resume()
        #expect(f.controller.state == .complete && f.controller.isFenced)
        #expect(try f.receipts.load() == nil)
        #expect(throws: SyncJournalStoreError.cloudAccountDeleted) { try f.store.stage() }
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func ambiguousNetworkFailureSurvivesReopenAndNotFoundCannotResumeUploads() async throws {
        let f = try fixture()
        await f.transport.setOffline(true)
        _ = try f.controller.prepare(accountID: f.account)
        await f.controller.submit(identityToken: Data("fresh-token".utf8), authorizationCode: Data("fresh-code".utf8))
        #expect(f.controller.state == .unconfirmed && f.controller.isFenced)
        #expect(try f.receipts.load()?.phase == .sent)
        #expect(throws: CloudDeletionError.requestMayHaveBeenSent) { try f.controller.cancelPrepared() }
        await f.transport.setOffline(false)
        let reopened = CloudDeletionController(container: f.container, receipts: f.receipts, transport: f.transport, stopped: {})
        await reopened.resume()
        #expect(reopened.state == .unconfirmed && reopened.isFenced)
        #expect(try f.receipts.load()?.phase == .sent)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func forgedReceiptOrWrongAccountCannotCloseOrReplaceTheLocalBinding() async throws {
        let f = try fixture()
        #expect(throws: SyncJournalError.accountMismatch) { try f.controller.prepare(accountID: UUID()) }
        _ = try f.controller.prepare(accountID: f.account)
        await f.transport.forgeReceipt()
        await f.controller.submit(identityToken: Data("fresh-token".utf8), authorizationCode: Data("fresh-code".utf8))
        #expect(f.controller.state == .unconfirmed)
        #expect(try f.store.journal()?.accountID == f.account)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func foregroundResumeCannotReplaceAnInFlightDeletionWithAnUnconfirmedLookup() async throws {
        let f = try fixture()
        await f.transport.pauseRequest()
        _ = try f.controller.prepare(accountID: f.account)
        let submission = Task {
            await f.controller.submit(identityToken: Data("fresh-token".utf8), authorizationCode: Data("fresh-code".utf8))
        }
        await f.transport.waitForRequest()
        await f.controller.resume()
        #expect(f.controller.state == .submitting)
        #expect(await f.transport.statusCount == 0)
        await f.transport.resumeRequest()
        await submission.value
        #expect(f.controller.state == .pending)
    }

    @Test
    func accountCompositionChecksAmbiguousReceiptsBeforeRestoringAuthentication() async throws {
        let f = try fixture()
        let intent = try f.receipts.prepare(accountID: f.account, workspaceID: try #require(try f.store.journal()?.workspaceID))
        try f.receipts.advance(intent, to: .sent)
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let authentication = DeletionSurfaceAuthentication(account: f.account)
        let session = CloudAccountSession(authentication: authentication, preferences: preferences, connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session, deletion: f.controller, deletionAvailable: true)
        await model.restore()
        #expect(await authentication.restoreCount == 0)
        #expect(f.controller.state == .unconfirmed && f.controller.isFenced)
        #expect(model.prepareAppleSignIn() == nil)
    }

    @Test
    func coldDeletionRetryAuthenticatesOnlyTheBoundAccountWithoutStartingSync() async throws {
        let f = try fixture()
        let intent = try f.receipts.prepare(accountID: f.account, workspaceID: try #require(try f.store.journal()?.workspaceID))
        try f.receipts.advance(intent, to: .sent)
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        CloudAccountSession.chooseLocalOnly(in: preferences)
        var activations = 0
        let authentication = DeletionSurfaceAuthentication(account: f.account)
        let session = CloudAccountSession(authentication: authentication, preferences: preferences,
            connected: { _ in activations += 1 }, stopped: {})
        let model = BackupSyncModel(session: session, deletion: f.controller, deletionAvailable: true)
        await model.restore()
        #expect(model.accountState == .localOnly && f.controller.state == .unconfirmed)
        _ = try #require(model.prepareCloudDeletion())
        await model.completeCloudDeletion(identityToken: Data("fresh-token".utf8), authorizationCode: Data("fresh-code".utf8))
        #expect(f.controller.state == .pending)
        #expect(activations == 0)
        #expect(CloudAccountSession.prefersLocalOnly(in: preferences))
        #expect(try f.receipts.load()?.operationID == intent.operationID)
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    @Test
    func coldRetryRejectsAnotherAppleAccountBeforeSendingDeletion() async throws {
        let f = try fixture()
        let intent = try f.receipts.prepare(accountID: f.account, workspaceID: try #require(try f.store.journal()?.workspaceID))
        try f.receipts.advance(intent, to: .sent)
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        var activations = 0
        let authentication = DeletionSurfaceAuthentication(account: UUID())
        let session = CloudAccountSession(authentication: authentication, preferences: preferences,
            connected: { _ in activations += 1 }, stopped: {})
        let model = BackupSyncModel(session: session, deletion: f.controller, deletionAvailable: true)
        await model.restore()
        _ = try #require(model.prepareCloudDeletion())
        await model.completeCloudDeletion(identityToken: Data("wrong-token".utf8), authorizationCode: Data("fresh-code".utf8))
        #expect(f.controller.isFenced && f.controller.state == .unconfirmed)
        #expect(await f.transport.requestCount == 0)
        #expect(await authentication.signOutCount == 1)
        #expect(activations == 0 && model.alert != nil)
    }

    @Test
    func nativeDeletionConsumesItsOwnChallengeAndSignsOutOnlyAfterConfirmedQueue() async throws {
        let f = try fixture()
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let authentication = DeletionSurfaceAuthentication(account: f.account)
        let session = CloudAccountSession(authentication: authentication, preferences: preferences, connected: { _ in }, stopped: {})
        let model = BackupSyncModel(session: session, deletion: f.controller, deletionAvailable: true)
        await model.restore()
        await model.completeCloudDeletion(identityToken: Data("unsolicited".utf8), authorizationCode: Data("unsolicited".utf8))
        #expect(await f.transport.requestCount == 0)
        #expect(await authentication.signOutCount == 0)
        _ = try #require(model.prepareCloudDeletion())
        await model.completeCloudDeletion(identityToken: Data("fresh-token".utf8), authorizationCode: Data("fresh-code".utf8))
        #expect(f.controller.state == .pending)
        #expect(model.accountState == .localOnly)
        #expect(await authentication.signOutCount == 1)
        #expect(CloudAccountSession.prefersLocalOnly(in: preferences))
        #expect(try SyncGraphCodec.capture(in: ModelContext(f.container)) == f.graph)
    }

    private func fixture() throws -> (container: ModelContainer, account: UUID, receipts: CloudDeletionReceiptStore,
                                     store: SyncJournalStore, transport: DeletionControllerTransport,
                                     controller: CloudDeletionController, graph: [SyncRecord]) {
        let container = try ModelContainerFactory.inMemoryTest()
        container.mainContext.insert(Client(name: "Keep My Business"))
        try container.mainContext.save()
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let receipts = CloudDeletionReceiptStore(storage: SyncTestAuthStorage())
        let transport = DeletionControllerTransport()
        let controller = CloudDeletionController(container: container, receipts: receipts, transport: transport, stopped: {})
        return (container, account, receipts, store, transport, controller,
                try SyncGraphCodec.capture(in: ModelContext(container)))
    }
}

private actor DeletionSurfaceAuthentication: CloudAccountAuthentication {
    let account: UUID
    private(set) var restoreCount = 0
    private(set) var signOutCount = 0
    init(account: UUID) { self.account = account }
    func currentAccountID() async throws -> UUID { restoreCount += 1; return account }
    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async throws -> UUID { account }
    func signOut() async throws { signOutCount += 1 }
}

private actor DeletionControllerTransport: CloudDeletionTransport {
    private var offline = false
    private var complete = false
    private var forged = false
    private var accepted: UUID?
    private var pause = false
    private var loseReceipt = false
    private var paused: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var requestCount = 0
    private(set) var statusCount = 0
    func request(_ intent: CloudDeletionIntent, identityToken: Data, authorizationCode: Data,
                 challenge: AppleSignInChallenge) async throws -> CloudDeletionStatus {
        requestCount += 1
        if pause {
            pause = false
            await withCheckedContinuation { continuation in
                paused = continuation; started?.resume(); started = nil
            }
        }
        if offline { throw URLError(.networkConnectionLost) }
        if forged { return .pending(UUID()) }
        accepted = intent.operationID
        if loseReceipt { loseReceipt = false; throw URLError(.networkConnectionLost) }
        return .pending(intent.operationID)
    }
    func status(_ intent: CloudDeletionIntent) async throws -> CloudDeletionStatus {
        statusCount += 1
        if offline { throw URLError(.notConnectedToInternet) }
        guard accepted == intent.operationID else { return .notFound }
        return complete ? .complete(intent.operationID) : .pending(intent.operationID)
    }
    func setOffline(_ value: Bool) { offline = value }
    func setComplete() { complete = true }
    func loseNextReceipt() { loseReceipt = true }
    func forgeReceipt() { forged = true }
    func pauseRequest() { pause = true }
    func waitForRequest() async {
        if paused != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func resumeRequest() { paused?.resume(); paused = nil }
}
