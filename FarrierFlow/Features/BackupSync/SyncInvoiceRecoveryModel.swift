import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SyncInvoiceRecoveryModel {
    private let container: ModelContainer
    private let store: SyncJournalStore
    private let transport: any SyncTransport
    private let currentAccount: @MainActor () -> UUID?
    @ObservationIgnored private var epoch = UUID()
    private(set) var review: SyncInvoiceRecoveryReview?
    private(set) var isBusy = false

    init(container: ModelContainer, transport: any SyncTransport,
         currentAccount: @escaping @MainActor () -> UUID?) {
        self.container = container
        self.store = SyncJournalStore(container: container)
        self.transport = transport
        self.currentAccount = currentAccount
    }

    func cancel() { epoch = UUID(); review = nil }

    func load(accountID: UUID) async throws {
        guard !isBusy else { throw SyncInvoiceRecoveryError.changedSinceReview }
        guard currentAccount() == accountID else { throw SyncJournalError.accountMismatch }
        guard !container.mainContext.hasChanges else { throw SyncGraphError.unsavedChanges }
        guard let journal = try store.journal() else { throw SyncJournalStoreError.unbound }
        try journal.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
        if let pending = journal.pending {
            guard journal.confirmedRejection?.batch == pending else { throw SyncJournalError.pendingUpload }
        }
        let original = try SyncGraphCodec.capture(in: ModelContext(container))
        let generation = UUID()
        epoch = generation
        review = nil
        isBusy = true
        defer { isBusy = false }
        let initial = try await transport.bootstrap(deviceID: journal.deviceID)
        try check(accountID, generation: generation)
        guard initial.workspaceID == journal.workspaceID else { throw SyncJournalError.accountMismatch }
        guard (initial.minimumProtocolVersion ?? 1) <= SyncProtocolVersion.deletion.rawValue else {
            throw SyncTransportError.updateRequired(initial.minimumProtocolVersion ?? 1)
        }
        var records = try SyncJournal.index(journal.baseline)
        var revisions = journal.revisions
        var cursor = journal.cursor
        var deletedPhotoIDs: Set<UUID> = []
        var page: SyncPullPage
        repeat {
            page = try await transport.pull(workspaceID: journal.workspaceID, cursor: cursor, protocolVersion: .deletion)
            try check(accountID, generation: generation)
            guard page.workspaceID == journal.workspaceID else { throw SyncJournalError.accountMismatch }
            for transaction in page.transactions {
                guard cursor < Int64.max, transaction.workspaceID == journal.workspaceID,
                      transaction.revision == cursor + 1 else { throw SyncJournalError.invalidCursor }
                var seen: Set<UUID> = []
                for mutation in transaction.mutations {
                    guard seen.insert(mutation.id).inserted else { throw SyncJournalError.invalidMutation }
                    if transaction.revision <= (revisions[mutation.id] ?? 0) { continue }
                    guard mutation.expectedRevision == (revisions[mutation.id] ?? 0),
                          mutation.record == nil || (mutation.record?.id == mutation.id &&
                            mutation.record?.kind == mutation.kind),
                          records[mutation.id]?.kind == nil || records[mutation.id]?.kind == mutation.kind else {
                        throw SyncJournalError.invalidMutation
                    }
                    if mutation.kind == .photograph, mutation.record == nil { deletedPhotoIDs.insert(mutation.id) }
                    records[mutation.id] = mutation.record
                    revisions[mutation.id] = transaction.revision
                }
                cursor = transaction.revision
            }
            guard page.cursor == cursor, !page.hasMore || !page.transactions.isEmpty else {
                throw SyncJournalError.invalidCursor
            }
        } while page.hasMore
        let latest = try await transport.bootstrap(deviceID: journal.deviceID)
        try check(accountID, generation: generation)
        guard latest.workspaceID == journal.workspaceID, latest.revision == cursor,
              latest.invoicingDeviceID == page.invoicingDeviceID,
              latest.invoicingGeneration == page.invoicingGeneration,
              try store.journal() == journal,
              try SyncGraphCodec.capture(in: ModelContext(container)) == original,
              !container.mainContext.hasChanges else { throw SyncInvoiceRecoveryError.changedSinceReview }
        let snapshot = SyncRecoveryCloudSnapshot(workspaceID: journal.workspaceID, revision: cursor,
            records: records.values.sorted { $0.id.uuidString < $1.id.uuidString }, revisions: revisions,
            invoicingDeviceID: latest.invoicingDeviceID, invoicingGeneration: latest.invoicingGeneration,
            deletedPhotoIDs: deletedPhotoIDs)
        review = try SyncInvoiceRecoveryReview.make(current: original, journal: journal,
            cloud: snapshot, capturedAt: Date())
    }

    func confirm(accountID: UUID, settings: SyncRecoverySettingsChoice) async throws {
        guard !isBusy, let review else { throw SyncInvoiceRecoveryError.changedSinceReview }
        try check(accountID, generation: epoch)
        let generation = epoch
        isBusy = true
        defer { isBusy = false }
        let latest = try await transport.bootstrap(deviceID: review.journal.deviceID)
        try check(accountID, generation: generation)
        guard latest.workspaceID == review.cloud.workspaceID, latest.revision == review.cloud.revision,
              latest.invoicingDeviceID == review.cloud.invoicingDeviceID,
              latest.invoicingGeneration == review.cloud.invoicingGeneration else {
            throw SyncInvoiceRecoveryError.changedSinceReview
        }
        try store.applyRecovery(review, settings: settings)
        self.review = nil
    }

    private func check(_ accountID: UUID, generation: UUID) throws {
        try Task.checkCancellation()
        guard epoch == generation else { throw CancellationError() }
        guard currentAccount() == accountID else { throw SyncJournalError.accountMismatch }
    }
}
