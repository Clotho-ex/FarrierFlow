import Foundation
import Observation
import SwiftData
import Synchronization

nonisolated enum BackupSyncRunState: Equatable, Sendable {
    case localOnly, pending, syncingRecords, syncingPhotos, upToDate
    case waitingForConnection, waitingForSavedChanges, needsReview, missingPhotos, updateRequired, failed
}

@MainActor
@Observable
final class BackupSyncRuntime {
    private let container: ModelContainer
    private let deviceID: UUID
    private let store: SyncJournalStore
    private let transport: any SyncTransport
    private let coordinator: SyncCoordinator
    private let photographs: SyncPhotographTransfer
    private nonisolated let tasks = Mutex<[UUID: Task<Void, Never>]>([:])
    @ObservationIgnored private var epoch = UUID()
    @ObservationIgnored private var runningID: UUID?
    @ObservationIgnored private var requested = false
    @ObservationIgnored private var reviewing = false
    @ObservationIgnored private var lastGraph: [SyncRecord] = []

    private(set) var accountID: UUID?
    private(set) var workspaceID: UUID?
    private(set) var state: BackupSyncRunState = .localOnly
    private(set) var status: SyncProtectionStatus?
    private(set) var recordsVersion = UUID()
    private(set) var photographsVersion = UUID()
    private(set) var restoredBusinessVersion: UUID?
    private(set) var invoicingDeviceID: UUID?
    private(set) var invoicingGeneration: Int64 = 0
    var isInvoicingPhone: Bool { accountID != nil && invoicingDeviceID == deviceID && invoicingGeneration > 0 }
    var canTakeOverInvoicing: Bool {
        accountID != nil && workspaceID != nil && invoicingDeviceID != nil &&
            !isInvoicingPhone && invoicingGeneration > 0 && runningID == nil && !reviewing && status?.conflictCount == 0
    }

    func requestInvoicingTakeover() {
        guard canTakeOverInvoicing else { return }
        let id = UUID(), generation = epoch
        runningID = id
        state = .syncingRecords
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks.withLock { $0[id] = nil } }
            do {
                try self.check(generation)
                try await self.coordinator.takeOverInvoicing()
                try self.check(generation)
                try self.refreshStatus()
                self.state = .pending
                if self.runningID == id { self.runningID = nil; self.requestSync() }
            } catch {
                guard self.epoch == generation, self.accountID != nil else { return }
                if self.runningID == id { self.runningID = nil }
                self.requested = false
                if error is URLError { self.state = .waitingForConnection }
                else if error as? SyncGraphError == .unsavedChanges { self.state = .waitingForSavedChanges }
                else if error as? SyncJournalError == .unresolvedConflicts { self.state = .needsReview }
                else if case SyncTransportError.updateRequired = error { self.state = .updateRequired }
                else { self.state = .failed }
                do { try self.refreshStatus() } catch { self.state = .failed }
            }
        }
        tasks.withLock { $0[id] = task }
    }

    init(container: ModelContainer, transport: any SyncTransport,
         photoTransport: any SyncPhotoTransport, library: PhotographLibrary, deviceID: UUID) {
        self.container = container
        self.deviceID = deviceID
        self.transport = transport
        store = SyncJournalStore(container: container)
        coordinator = SyncCoordinator(container: container, transport: transport, deviceID: deviceID)
        photographs = SyncPhotographTransfer(store: store, library: library, transport: photoTransport)
    }

    func connect(accountID: UUID) throws {
        if let journal = try store.journal(), journal.accountID != accountID {
            throw SyncJournalError.accountMismatch
        }
        if self.accountID == accountID { requestSync(); return }
        stop()
        self.accountID = accountID
        coordinator.activate(accountID: accountID)
        state = .pending
        requestSync()
    }

    func stop() {
        epoch = UUID()
        accountID = nil
        runningID = nil
        requested = false
        reviewing = false
        tasks.withLock { for task in $0.values { task.cancel() } }
        coordinator.deactivate()
        state = .localOnly
    }

    func requestSync() {
        guard accountID != nil, !reviewing else { return }
        requested = true
        guard runningID == nil else { return }
        let id = UUID()
        let generation = epoch
        runningID = id
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.tasks.withLock { $0[id] = nil } }
            await self.run(generation: generation, id: id)
        }
        tasks.withLock { $0[id] = task }
    }

    func prepareRecovery(currentAccount: @escaping @MainActor () -> UUID?) async throws -> SyncInvoiceRecoveryModel {
        guard accountID != nil else { throw SyncJournalError.accountMismatch }
        reviewing = true
        epoch = UUID()
        requested = false
        runningID = nil
        tasks.withLock { for task in $0.values { task.cancel() } }
        coordinator.deactivate()
        await waitUntilIdle()
        guard accountID != nil, currentAccount() == accountID else { throw SyncJournalError.accountMismatch }
        state = .needsReview
        return SyncInvoiceRecoveryModel(container: container, transport: transport, currentAccount: currentAccount)
    }

    func finishRecoveryReview() {
        guard reviewing, let accountID else { return }
        reviewing = false
        coordinator.activate(accountID: accountID)
        requestSync()
    }

    /// Also joins cancelled generations, so late work cannot outlive its owner.
    func waitUntilIdle() async {
        while true {
            let outstanding = tasks.withLock { Array($0.values) }
            guard !outstanding.isEmpty else { return }
            for task in outstanding { await task.value }
        }
    }

    @discardableResult
    func refreshStatus() throws -> Bool {
        let graph = try SyncGraphCodec.capture(in: ModelContext(container))
        let journal = try store.journal()
        workspaceID = journal?.workspaceID
        invoicingDeviceID = journal?.invoicingDeviceID
        invoicingGeneration = journal?.invoicingGeneration ?? 0
        status = try SyncProtectionStatus.make(current: graph, journal: journal)
        if state == .upToDate, status?.isActiveDataProtected != true { state = .pending }
        let changed = graph != lastGraph
        if changed {
            lastGraph = graph
            recordsVersion = UUID()
        }
        return changed
    }

    /// Filter synchronously at publication. SwiftUI may buffer a notification
    /// beyond the lifetime of an isolated archive/validation container, whose
    /// ModelContext.container getter then traps instead of returning nil.
    func acceptsSaveNotification(_ notification: Notification) -> Bool {
        guard let context = notification.object as? ModelContext,
              context.container === container else { return false }
        return true
    }

    func didSave(_ notification: Notification) {
        guard acceptsSaveNotification(notification) else { return }
        let identifiers = ModelSaveChanges.identifiers(in: notification)
        // Journal checkpoints are saves too. They must not create an endless
        // upload/checkpoint/upload cycle. Older runtimes may omit identifiers.
        if !identifiers.isEmpty {
            guard identifiers.contains(where: { $0.entityName != "SyncState" }) else { return }
        }
        do {
            let changed = try refreshStatus()
            if !identifiers.isEmpty || changed { requestSync() }
        } catch { state = .failed }
    }

    private func run(generation: UUID, id: UUID) async {
        defer { if runningID == id { runningID = nil } }
        while requested {
            guard epoch == generation, accountID != nil, runningID == id else { return }
            requested = false
            do {
                try check(generation)
                state = .syncingRecords
                try refreshStatus()
                try await coordinator.sync()
                try check(generation)
                try refreshStatus()
                if coordinator.didRestoreBusinessProfile { restoredBusinessVersion = UUID() }
                state = .syncingPhotos
                guard let accountID else { throw CancellationError() }
                let report = try await photographs.sync(accountID: accountID, checking: { [weak self] in
                    guard let self else { throw CancellationError() }
                    try self.check(generation)
                })
                try check(generation)
                try refreshStatus()
                photographsVersion = UUID()
                if !report.needsReviewIDs.isEmpty { state = .needsReview }
                else if !report.missingIDs.isEmpty { state = .missingPhotos }
                else { state = status?.isActiveDataProtected == true ? .upToDate : .pending }
            } catch {
                guard epoch == generation, accountID != nil else { return }
                if error is CancellationError { return }
                requested = false
                if error is URLError { state = .waitingForConnection }
                else if error as? SyncJournalError == .unresolvedConflicts { state = .needsReview }
                else if error as? SyncGraphError == .unsavedChanges { state = .waitingForSavedChanges }
                else if case SyncTransportError.updateRequired = error { state = .updateRequired }
                else { state = .failed }
                do { try refreshStatus() }
                catch { state = .failed }
                return
            }
        }
    }

    private func check(_ generation: UUID) throws {
        try Task.checkCancellation()
        guard accountID != nil, epoch == generation else { throw CancellationError() }
    }

    deinit {
        tasks.withLock { for task in $0.values { task.cancel() } }
    }
}
