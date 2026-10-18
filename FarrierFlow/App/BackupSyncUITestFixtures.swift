#if DEBUG
import Foundation
import Supabase
import SwiftData
import Synchronization

@MainActor
enum BackupSyncUITestFixtures {
    static func make(container: ModelContainer, preferences: UserDefaults) throws -> BackupSyncModel? {
        guard ProcessInfo.processInfo.environment[UITestLaunchConfiguration.scenarioEnvironmentKey] == "app-store-showcase",
              let state = ProcessInfo.processInfo.environment["FARRIERFLOW_UI_TEST_CLOUD_STATE"],
              ["connected", "pending", "unconfirmed", "history", "recovery", "offline"].contains(state) else { return nil }
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: container)
        let device = UUID()
        try store.bind(accountID: account, workspaceID: workspace, deviceID: device)
        if state == "offline" {
            let runtime = BackupSyncRuntime(container: container, transport: OfflineUITestTransport(),
                photoTransport: RecoveryUITestPhotos(), library: .init(container: container,
                    fileStore: .init(rootURL: FileManager.default.temporaryDirectory.appending(path: "UI-Offline-\(account)"))), deviceID: device)
            let session = CloudAccountSession(authentication: DeletionUITestAuthentication(account: account),
                preferences: preferences, connected: { id in try runtime.connect(accountID: id) }, stopped: { runtime.stop() })
            return BackupSyncModel(session: session, runtime: runtime, preferences: preferences)
        }
        if state == "history" || state == "recovery" {
            let records = try SyncGraphCodec.capture(in: container.mainContext)
            let invoiceIDs = records.filter { $0.kind == .invoice }.map(\.id)
            guard !invoiceIDs.isEmpty else { throw InvoiceHistoryError.invoiceUnavailable }
            if state == "history" {
                let archive = try InvoiceHistoryArchive(accountID: account, workspaceID: workspace,
                    capturedAt: Date(), reason: .numberCollision, sourceOperationID: nil,
                    records: records, invoiceIDs: invoiceIDs)
                try store.update { try $0.addArchive(archive) }
                return BackupSyncModel(preferences: preferences)
            }
            let replacement = Dictionary(uniqueKeysWithValues: records.map { ($0.id, UUID()) })
            let cloud = records.map { record in
                var fields = record.fields
                for (key, value) in fields {
                    if case .string(let text) = value, let id = UUID(uuidString: text), let mapped = replacement[id] {
                        fields[key] = .string(mapped.uuidString.lowercased())
                    }
                }
                return SyncRecord(id: replacement[record.id] ?? record.id, kind: record.kind, fields: fields)
            }
            let transport = RecoveryUITestTransport(workspace: workspace, records: cloud)
            let runtime = BackupSyncRuntime(container: container, transport: transport,
                photoTransport: RecoveryUITestPhotos(), library: .init(container: container,
                    fileStore: .init(rootURL: FileManager.default.temporaryDirectory.appending(path: "UI-Recovery-\(account)"))), deviceID: device)
            let session = CloudAccountSession(authentication: DeletionUITestAuthentication(account: account),
                preferences: preferences, connected: { id in try runtime.connect(accountID: id) }, stopped: { runtime.stop() })
            guard let batch = try store.stage() else { throw SyncJournalError.invalidMutation }
            try store.recordConfirmedRejection(operationID: batch.operationID, reason: .invoiceNumberCollision)
            return BackupSyncModel(session: session, runtime: runtime, preferences: preferences)
        }
        let receipts = CloudDeletionReceiptStore(storage: DeletionUITestStorage())
        if state != "connected" {
            let intent = try receipts.prepare(accountID: account, workspaceID: workspace)
            try receipts.advance(intent, to: state == "pending" ? .queued : .sent)
            if state == "pending" { try store.recordCloudDeletion(intent, status: .pending(intent.operationID)) }
        }
        let deletion = CloudDeletionController(container: container, receipts: receipts,
            transport: DeletionUITestTransport(completes: state == "pending"), stopped: {})
        let session = CloudAccountSession(authentication: DeletionUITestAuthentication(account: account),
            preferences: preferences, connected: { _ in }, stopped: {})
        return BackupSyncModel(session: session, preferences: preferences, deletion: deletion, deletionAvailable: true)
    }
}

private actor OfflineUITestTransport: SyncTransport {
    func bootstrap(deviceID: UUID) async throws -> SyncWorkspaceInfo {
        try await Task.sleep(for: .seconds(2))
        throw URLError(.notConnectedToInternet)
    }
    func push(_ batch: SyncBatch) throws -> SyncPushReceipt { throw URLError(.notConnectedToInternet) }
    func pull(workspaceID: UUID, cursor: Int64) throws -> SyncPullPage { throw URLError(.notConnectedToInternet) }
}

nonisolated private struct DeletionUITestAuthentication: CloudAccountAuthentication {
    let account: UUID
    func currentAccountID() async throws -> UUID { account }
    func signIn(identityToken: Data, challenge: AppleSignInChallenge) async throws -> UUID {
        throw CloudDeletionError.unavailable
    }
    func signOut() async throws {}
}

private actor RecoveryUITestTransport: SyncTransport {
    let workspace: UUID
    let records: [SyncRecord]
    private let primary = UUID()
    private var changes: [SyncRemoteTransaction] = []
    init(workspace: UUID, records: [SyncRecord]) { self.workspace = workspace; self.records = records }
    func bootstrap(deviceID: UUID) -> SyncWorkspaceInfo {
        .init(workspaceID: workspace, deviceID: deviceID, invoicingDeviceID: primary,
            invoicingGeneration: 2, revision: Int64(changes.count + 1), minimumProtocolVersion: 2)
    }
    func push(_ batch: SyncBatch) throws -> SyncPushReceipt {
        if batch.mutations.contains(where: { $0.kind == .invoice && $0.record != nil }) {
            throw SyncTransportError.confirmedRejection(.invoiceNumberCollision)
        }
        let revision = Int64(changes.count + 2)
        changes.append(.init(workspaceID: workspace, revision: revision, mutations: batch.mutations))
        return .init(operationID: batch.operationID, revision: revision)
    }
    func pull(workspaceID: UUID, cursor: Int64) -> SyncPullPage {
        let initial = SyncRemoteTransaction(workspaceID: workspace, revision: 1,
            mutations: records.map { .init(id: $0.id, kind: $0.kind, expectedRevision: 0, record: $0) })
        return .init(workspaceID: workspace, cursor: Int64(changes.count + 1), hasMore: false,
            transactions: ([initial] + changes).filter { $0.revision > cursor },
            invoicingDeviceID: primary, invoicingGeneration: 2)
    }
}

private actor RecoveryUITestPhotos: SyncPhotoTransport {
    func manifest(workspaceID: UUID) throws -> [SyncPhotoManifestEntry] { throw SyncTransportError.unsupportedOperation }
    func upload(workspaceID: UUID, payload: SyncPhotoPayload) throws { throw SyncTransportError.unsupportedOperation }
    func download(workspaceID: UUID, photoID: UUID) throws -> Data { throw SyncTransportError.unsupportedOperation }
    func commit(workspaceID: UUID, payload: SyncPhotoPayload) throws -> SyncPhotoManifestEntry { throw SyncTransportError.unsupportedOperation }
    func delete(workspaceID: UUID, photoID: UUID) throws { throw SyncTransportError.unsupportedOperation }
}

private actor DeletionUITestTransport: CloudDeletionTransport {
    let completes: Bool
    private var checks = 0
    init(completes: Bool) { self.completes = completes }
    func request(_ intent: CloudDeletionIntent, identityToken: Data, authorizationCode: Data,
                 challenge: AppleSignInChallenge) async throws -> CloudDeletionStatus {
        throw CloudDeletionError.unavailable
    }
    func status(_ intent: CloudDeletionIntent) async throws -> CloudDeletionStatus {
        checks += 1
        guard completes else { return .notFound }
        return checks > 1 ? .complete(intent.operationID) : .pending(intent.operationID)
    }
}

nonisolated private final class DeletionUITestStorage: AuthLocalStorage, Sendable {
    private let values = Mutex<[String: Data]>([:])
    func store(key: String, value: Data) throws { values.withLock { $0[key] = value } }
    func retrieve(key: String) throws -> Data? { values.withLock { $0[key] } }
    func remove(key: String) throws { values.withLock { $0[key] = nil } }
}
#endif
