import Foundation
import SwiftData

nonisolated enum SyncCoordinatorError: Error, Equatable {
    case alreadyRunning
}

@MainActor
final class SyncCoordinator {
    private let container: ModelContainer
    private let store: SyncJournalStore
    private let transport: any SyncTransport
    private let deviceID: UUID
    private var accountID: UUID?
    private var accountEpoch = UUID()
    private var runningID: UUID?
    private(set) var didRestoreBusinessProfile = false

    init(container: ModelContainer, transport: any SyncTransport, deviceID: UUID) {
        self.container = container
        store = SyncJournalStore(container: container)
        self.transport = transport
        self.deviceID = deviceID
    }

    func activate(accountID: UUID) {
        guard self.accountID != accountID else { return }
        self.accountID = accountID
        accountEpoch = UUID()
        runningID = nil
    }

    func deactivate() {
        accountID = nil
        accountEpoch = UUID()
        runningID = nil
    }

    func takeOverInvoicing() async throws {
        guard !container.mainContext.hasChanges else { throw SyncGraphError.unsavedChanges }
        guard let accountID else { throw CancellationError() }
        let epoch = accountEpoch
        // Settle exact pending operations and refetch current authority first.
        // A lost takeover receipt may already designate this physical device.
        try await sync()
        try check(epoch)
        guard let journal = try store.journal() else { throw SyncJournalStoreError.unbound }
        try journal.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
        if journal.invoicingDeviceID == deviceID { return }
        guard runningID == nil else { throw SyncCoordinatorError.alreadyRunning }
        let run = UUID()
        runningID = run
        defer { if runningID == run { runningID = nil } }
        let receipt = try await transport.takeOverInvoicing(workspaceID: journal.workspaceID,
            deviceID: deviceID, generation: journal.invoicingGeneration)
        try check(epoch)
        guard receipt.revision > journal.cursor else { throw SyncTransportError.invalidResponse }
        // Do not jump over the takeover commit or trust a receipt as a cursor.
        try await pull(workspaceID: journal.workspaceID, epoch: epoch)
        try check(epoch)
        guard let latest = try store.journal(), latest.cursor >= receipt.revision,
              latest.invoicingDeviceID == deviceID, latest.invoicingGeneration == receipt.invoicingGeneration else {
            throw SyncTransportError.revisionConflict
        }
    }

    func sync() async throws {
        guard let accountID else { throw CancellationError() }
        guard runningID == nil else { throw SyncCoordinatorError.alreadyRunning }
        if let journal = try store.journal(), journal.accountID != accountID {
            throw SyncJournalError.accountMismatch
        }
        let epoch = accountEpoch
        let run = UUID()
        runningID = run
        didRestoreBusinessProfile = false
        defer { if runningID == run { runningID = nil } }
        try check(epoch)
        let info = try await transport.bootstrap(deviceID: deviceID)
        try check(epoch)
        try store.bind(accountID: accountID, workspaceID: info.workspaceID, deviceID: deviceID)
        try store.update {
            $0.invoicingGeneration = info.invoicingGeneration
            $0.invoicingDeviceID = info.invoicingDeviceID
        }

        // A request with a lost receipt must be retried byte-for-byte before
        // pulling its possible commit. The server returns its cached receipt.
        if try store.journal()?.confirmedRejection != nil { throw SyncJournalError.unresolvedConflicts }
        if let pending = try store.journal()?.pending {
            try await push(pending, epoch: epoch)
        }
        if (info.minimumProtocolVersion ?? 1) > SyncProtocolVersion.deletion.rawValue {
            throw SyncTransportError.updateRequired(info.minimumProtocolVersion ?? 1)
        }
        while true {
            try await pull(workspaceID: info.workspaceID, epoch: epoch)
            try check(epoch)
            guard let batch = try store.stage() else { break }
            try await push(batch, epoch: epoch)
        }
        try check(epoch)
        try store.update { $0.lastSuccessfulSync = .now }
    }

    private func push(_ batch: SyncBatch, epoch: UUID) async throws {
        do {
            let protocolVersion = try store.journal()?.pendingProtocol ?? .legacy
            let receipt = try await transport.push(batch, protocolVersion: protocolVersion)
            try check(epoch)
            try store.acknowledge(operationID: receipt.operationID, revision: receipt.revision)
        } catch SyncTransportError.revisionConflict {
            try check(epoch)
            try store.update { try $0.reject(operationID: batch.operationID) }
        } catch SyncTransportError.invoicingDeviceRejected {
            try check(epoch)
            try store.recordConfirmedRejection(operationID: batch.operationID, reason: .invoicingAuthority)
            throw SyncJournalError.unresolvedConflicts
        } catch SyncTransportError.confirmedRejection(let reason) {
            try check(epoch)
            try store.recordConfirmedRejection(operationID: batch.operationID, reason: reason)
            throw SyncJournalError.unresolvedConflicts
        }
    }

    private func pull(workspaceID: UUID, epoch: UUID) async throws {
        var hasMore = true
        while hasMore {
            try check(epoch)
            guard let journal = try store.journal() else { throw SyncJournalStoreError.unbound }
            guard journal.deferredRemote == nil else { throw SyncJournalError.unresolvedConflicts }
            let page = try await transport.pull(workspaceID: workspaceID, cursor: journal.cursor,
                protocolVersion: .deletion)
            try check(epoch)
            for transaction in page.transactions {
                try check(epoch)
                if try store.receive(transaction) { didRestoreBusinessProfile = true }
            }
            try store.update {
                $0.invoicingGeneration = page.invoicingGeneration
                $0.invoicingDeviceID = page.invoicingDeviceID
            }
            hasMore = page.hasMore
        }
    }

    private func check(_ epoch: UUID) throws {
        try Task.checkCancellation()
        guard accountID != nil, accountEpoch == epoch else { throw CancellationError() }
    }
}
