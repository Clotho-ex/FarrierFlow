import Foundation

nonisolated enum SyncJournalError: Error, Equatable {
    case accountMismatch
    case duplicateIdentity(UUID)
    case identityKindChanged(UUID)
    case unexpectedAcknowledgment
    case invalidRevision
    case batchTooLarge
    case invalidCursor
    case invalidMutation
    case pendingUpload
    case unresolvedConflicts
}

/// The baseline is the exact acknowledged content, not whatever happens to be
/// on screen when a request returns. Committed local records remain the outbox
/// source even if the app is killed before the next sync attempt.
nonisolated struct SyncJournal: Codable, Equatable, Sendable {
    let accountID: UUID
    let workspaceID: UUID
    private(set) var deviceID: UUID
    private(set) var baseline: [SyncRecord] = []
    private(set) var revisions: [UUID: Int64] = [:]
    private(set) var pending: SyncBatch?
    private var pendingProtocolVersion: SyncProtocolVersion?
    var pendingProtocol: SyncProtocolVersion { pendingProtocolVersion ?? .legacy }
    private(set) var confirmedRejection: SyncConfirmedRejection?

    mutating func confirmRejection(operationID: UUID, reason: SyncPushRejectionReason) throws {
        guard let pending, pending.operationID == operationID else { throw SyncJournalError.unexpectedAcknowledgment }
        confirmedRejection = SyncConfirmedRejection(batch: pending, protocolVersion: pendingProtocol, reason: reason)
    }

    mutating func recoverCloudBaseline(_ cloud: SyncRecoveryCloudSnapshot) throws {
        guard cloud.workspaceID == workspaceID, cloud.revision >= cursor else { throw SyncJournalError.invalidCursor }
        if let pending {
            guard confirmedRejection?.batch == pending, confirmedRejection?.protocolVersion == pendingProtocol else {
                throw SyncJournalError.pendingUpload
            }
            try reject(operationID: pending.operationID)
        }
        baseline = cloud.records
        revisions = cloud.revisions
        cursor = cloud.revision
        invoicingDeviceID = cloud.invoicingDeviceID
        invoicingGeneration = cloud.invoicingGeneration
        conflicts = []
        deferredRemote = nil
        confirmedRejection = nil
    }
    var invoicingGeneration: Int64 = 0
    var invoicingDeviceID: UUID?
    var cursor: Int64 = 0
    var lastSuccessfulSync: Date?
    private(set) var conflicts: [SyncConflict] = []
    var deferredRemote: SyncRemoteTransaction?
    private(set) var photoReceipts: [SyncPhotoManifestEntry]?
    var verifiedPhotoReceipts: [SyncPhotoManifestEntry] { photoReceipts ?? [] }
    private var photoDeletions: [UUID]?
    var pendingPhotoDeletionIDs: [UUID] { photoDeletions ?? [] }
    var lastPhotographCheck: Date?
    var deletionOperationID: UUID?
    var deletionCompleted: Bool?
    private var invoiceHistory: [InvoiceHistoryArchive]?
    var invoiceHistoryArchives: [InvoiceHistoryArchive] { invoiceHistory ?? [] }

    @MainActor
    mutating func addArchive(_ archive: InvoiceHistoryArchive) throws {
        try verifyBinding(accountID: archive.accountID, workspaceID: archive.workspaceID)
        try archive.validate()
        if let existing = invoiceHistoryArchives.first(where: { $0.id == archive.id }) {
            guard existing == archive else { throw InvoiceHistoryError.immutableArchive }
            return
        }
        invoiceHistory = invoiceHistoryArchives + [archive]
    }

    init(accountID: UUID, workspaceID: UUID, deviceID: UUID) {
        self.accountID = accountID
        self.workspaceID = workspaceID
        self.deviceID = deviceID
    }

    mutating func confirmPhotoDeletion(id: UUID) throws {
        guard pendingPhotoDeletionIDs.contains(id), !baseline.contains(where: { $0.id == id }) else {
            throw SyncJournalError.unexpectedAcknowledgment
        }
        photoDeletions?.removeAll { $0 == id }
        photoReceipts?.removeAll { $0.id == id }
    }

    private mutating func queuePhotoDeletion(_ mutation: SyncMutation) {
        guard mutation.kind == .photograph, mutation.record == nil else { return }
        var deletions = Set(pendingPhotoDeletionIDs)
        deletions.insert(mutation.id)
        photoDeletions = deletions.sorted { $0.uuidString < $1.uuidString }
        photoReceipts?.removeAll { $0.id == mutation.id }
    }

    mutating func markPhotosVerified(_ entries: [SyncPhotoManifestEntry]) throws {
        let records = try Self.index(baseline)
        var receipts: [UUID: SyncPhotoManifestEntry] = [:]
        for receipt in verifiedPhotoReceipts where records[receipt.id]?.kind == .photograph {
            receipts[receipt.id] = receipt
        }
        for entry in entries {
            guard entry.isValid, let photo = records[entry.id], photo.kind == .photograph,
                  photo.fields["byteCount"] == .integer(entry.byteCount),
                  receipts[entry.id] == nil || receipts[entry.id] == entry else {
                throw SyncTransportError.invalidResponse
            }
            receipts[entry.id] = entry
        }
        photoReceipts = receipts.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    mutating func rebindDevice(to id: UUID) {
        // An already-staged operation keeps its originating device and UUID
        // for idempotent retry; future operations use this physical device.
        deviceID = id
    }

    mutating func resolveConflicts(_ choices: [UUID: SyncConflictChoice], current: [SyncRecord]) throws -> [SyncRecord] {
        guard pending == nil else { throw SyncJournalError.pendingUpload }
        guard deferredRemote == nil else { throw SyncJournalError.unresolvedConflicts }
        guard !conflicts.isEmpty, Set(choices.keys) == Set(conflicts.map(\.id)) else {
            throw SyncConflictResolutionError.incompleteChoices
        }
        var records = try Self.index(current)
        for conflict in conflicts {
            if choices[conflict.id] == .useCloud { records[conflict.id] = conflict.remote }
            else if conflict.remote == nil, records[conflict.id] != nil {
                // A tombstone is permanent; keeping a deleted identity would
                // resurrect it. Creating an explicit copy is a separate action.
                throw SyncConflictResolutionError.deletedIdentity
            }
        }
        conflicts = []
        return records.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func verifyBinding(accountID: UUID, workspaceID: UUID) throws {
        guard self.accountID == accountID, self.workspaceID == workspaceID else {
            throw SyncJournalError.accountMismatch
        }
    }

    mutating func stage(_ current: [SyncRecord]) throws -> SyncBatch? {
        guard conflicts.isEmpty, deferredRemote == nil, confirmedRejection == nil else {
            throw SyncJournalError.unresolvedConflicts
        }
        let currentByID = try Self.index(current)
        let baselineByID = try Self.index(baseline)
        for (id, record) in currentByID {
            if let old = baselineByID[id], old.kind != record.kind {
                throw SyncJournalError.identityKindChanged(id)
            }
        }
        if let pending { return pending }
        let mutations = Set(currentByID.keys).union(baselineByID.keys)
            .sorted { $0.uuidString < $1.uuidString }
            .compactMap { id -> SyncMutation? in
                let current = currentByID[id]
                let old = baselineByID[id]
                guard current != old, let kind = current?.kind ?? old?.kind else {
                    return nil
                }
                return SyncMutation(
                    id: id, kind: kind, expectedRevision: revisions[id] ?? 0,
                    record: current
                )
            }
        guard !mutations.isEmpty else { return nil }
        let operationID = UUID()
        let empty = SyncBatch(
            operationID: operationID, workspaceID: workspaceID, deviceID: deviceID,
            invoicingGeneration: invoicingGeneration, mutations: []
        )
        let selected = try SyncBatchPlanner.select(
            from: mutations, baseline: baseline,
            headerBytes: JSONEncoder().encode(empty).count
        )
        let batch = SyncBatch(
            operationID: operationID, workspaceID: workspaceID, deviceID: deviceID,
            invoicingGeneration: invoicingGeneration, mutations: selected
        )
        guard try JSONEncoder().encode(batch).count <= 10 * 1_024 * 1_024 else {
            throw SyncJournalError.batchTooLarge
        }
        pending = batch
        pendingProtocolVersion = .holds
        return batch
    }

    mutating func acknowledge(operationID: UUID, revision: Int64) throws {
        guard let pending, pending.operationID == operationID else {
            throw SyncJournalError.unexpectedAcknowledgment
        }
        guard revision > 0,
              pending.mutations.allSatisfy({ revision > $0.expectedRevision }) else {
            throw SyncJournalError.invalidRevision
        }
        var records = try Self.index(baseline)
        for mutation in pending.mutations {
            records[mutation.id] = mutation.record
            revisions[mutation.id] = revision
            queuePhotoDeletion(mutation)
        }
        baseline = records.values.sorted { $0.id.uuidString < $1.id.uuidString }
        self.pending = nil
        pendingProtocolVersion = nil
        confirmedRejection = nil
    }

    /// Only call after the server explicitly confirms its transaction failed.
    /// A timeout or cancellation is never sufficient to replace an operation.
    mutating func reject(operationID: UUID) throws {
        guard pending?.operationID == operationID else {
            throw SyncJournalError.unexpectedAcknowledgment
        }
        pending = nil
        pendingProtocolVersion = nil
        confirmedRejection = nil
    }

    static func index(_ records: [SyncRecord]) throws -> [UUID: SyncRecord] {
        var result: [UUID: SyncRecord] = [:]
        for record in records {
            guard result.updateValue(record, forKey: record.id) == nil else {
                throw SyncJournalError.duplicateIdentity(record.id)
            }
        }
        return result
    }

    mutating func receive(
        _ transaction: SyncRemoteTransaction, current: [SyncRecord]
    ) throws -> [SyncRecord] {
        guard transaction.workspaceID == workspaceID else {
            throw SyncJournalError.accountMismatch
        }
        guard cursor >= 0, transaction.revision > 0 else {
            throw SyncJournalError.invalidCursor
        }
        guard transaction.revision > cursor else { return current }
        guard cursor < Int64.max, transaction.revision == cursor + 1 else {
            throw SyncJournalError.invalidCursor
        }
        guard pending == nil else { throw SyncJournalError.pendingUpload }
        guard transaction.mutations.count <= 10_000 else {
            throw SyncJournalError.batchTooLarge
        }
        var updated = self
        var local = try Self.index(current)
        var baseline = try Self.index(self.baseline)
        var seen = Set<UUID>()
        for mutation in transaction.mutations {
            guard seen.insert(mutation.id).inserted,
                  mutation.expectedRevision >= 0,
                  mutation.expectedRevision < transaction.revision,
                  mutation.record == nil ||
                  (mutation.record?.id == mutation.id && mutation.record?.kind == mutation.kind)
            else { throw SyncJournalError.invalidMutation }
            // A retried upload may already be acknowledged while its older
            // commits are still being paged. Never regress that record.
            guard transaction.revision > (updated.revisions[mutation.id] ?? 0) else { continue }
            guard baseline[mutation.id]?.kind == nil || baseline[mutation.id]?.kind == mutation.kind,
                  local[mutation.id]?.kind == nil || local[mutation.id]?.kind == mutation.kind else {
                throw SyncJournalError.invalidMutation
            }
            updated.conflicts.removeAll { $0.id == mutation.id }
            switch SyncRecordMerge.merge(
                base: baseline[mutation.id], local: local[mutation.id],
                remote: mutation.record
            ) {
            case .merged(let record):
                local[mutation.id] = record
            case .conflict:
                updated.conflicts.append(SyncConflict(
                    id: mutation.id, kind: mutation.kind,
                    local: local[mutation.id], remote: mutation.record
                ))
            }
            baseline[mutation.id] = mutation.record
            updated.revisions[mutation.id] = transaction.revision
            updated.queuePhotoDeletion(mutation)
        }
        updated.baseline = baseline.values.sorted { $0.id.uuidString < $1.id.uuidString }
        updated.cursor = transaction.revision
        updated.deferredRemote = nil
        self = updated
        return local.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
