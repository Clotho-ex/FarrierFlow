import Foundation
import SwiftData

nonisolated enum SyncJournalStoreError: Error, Equatable {
    case unbound
    case duplicateState
    case cloudAccountDeleted
}

@MainActor
final class SyncJournalStore {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func journal() throws -> SyncJournal? {
        let context = ModelContext(container)
        guard let state = try Self.state(in: context) else { return nil }
        guard !state.cloudDeleted else { throw SyncJournalStoreError.cloudAccountDeleted }
        guard let data = state.journalData else { return nil }
        return try JSONDecoder().decode(SyncJournal.self, from: data)
    }

    func bind(accountID: UUID, workspaceID: UUID, deviceID: UUID) throws {
        let context = ModelContext(container)
        let state: FarrierFlowSchemaV5.SyncState
        if let existing = try Self.state(in: context) {
            state = existing
        } else {
            state = FarrierFlowSchemaV5.SyncState(deviceID: deviceID)
            context.insert(state)
        }
        guard !state.cloudDeleted else { throw SyncJournalStoreError.cloudAccountDeleted }
        if let data = state.journalData {
            var journal = try JSONDecoder().decode(SyncJournal.self, from: data)
            try journal.verifyBinding(accountID: accountID, workspaceID: workspaceID)
            journal.rebindDevice(to: deviceID)
            state.journalData = try JSONEncoder().encode(journal)
        } else {
            let journal = SyncJournal(
                accountID: accountID, workspaceID: workspaceID, deviceID: deviceID
            )
            state.journalData = try JSONEncoder().encode(journal)
        }
        state.deviceID = deviceID
        try context.save()
    }

    func stage() throws -> SyncBatch? {
        let context = ModelContext(container)
        var journal = try Self.read(in: context)
        let committed = try SyncGraphCodec.capture(in: context)
        let batch = try journal.stage(committed)
        try Self.write(journal, in: context)
        try context.save()
        return batch
    }

    func acknowledge(operationID: UUID, revision: Int64) throws {
        let context = ModelContext(container)
        var journal = try Self.read(in: context)
        try journal.acknowledge(operationID: operationID, revision: revision)
        try Self.write(journal, in: context)
        try context.save()
    }

    func update(_ change: (inout SyncJournal) throws -> Void) throws {
        let context = ModelContext(container)
        var journal = try Self.read(in: context)
        try change(&journal)
        try Self.write(journal, in: context)
        try context.save()
    }

    func recordConfirmedRejection(operationID: UUID, reason: SyncPushRejectionReason) throws {
        try update { try $0.confirmRejection(operationID: operationID, reason: reason) }
    }

    func applyRecovery(_ review: SyncInvoiceRecoveryReview, settings: SyncRecoverySettingsChoice) throws {
        guard !container.mainContext.hasChanges else { throw SyncGraphError.unsavedChanges }
        guard var journal = try journal(), journal == review.journal,
              try SyncGraphCodec.capture(in: ModelContext(container)) == review.current else {
            throw SyncInvoiceRecoveryError.changedSinceReview
        }
        let records = try review.resolved(settings: settings)
        if let archive = review.archive { try journal.addArchive(archive) }
        try journal.recoverCloudBaseline(review.cloud, current: records, resolvingConflictIDs: review.resolvedConflictIDs)
        if let archive = review.archive {
            try SyncGraphCodec.applyRecovery(records, archive: archive, in: container.mainContext, journal: journal)
        } else { try SyncGraphCodec.apply(records, in: container.mainContext, journal: journal) }
    }

    func recordCloudDeletion(_ intent: CloudDeletionIntent, status: CloudDeletionStatus) throws {
        guard intent.isValid else { throw CloudDeletionError.invalidResponse }
        switch status {
        case .pending(let id), .complete(let id):
            guard id == intent.operationID else { throw CloudDeletionError.invalidResponse }
        case .notFound: throw CloudDeletionError.invalidResponse
        }
        let context = ModelContext(container)
        guard let state = try Self.state(in: context), let data = state.journalData else { throw SyncJournalStoreError.unbound }
        var journal = try JSONDecoder().decode(SyncJournal.self, from: data)
        try journal.verifyBinding(accountID: intent.accountID, workspaceID: intent.workspaceID)
        guard journal.deletionOperationID == nil || journal.deletionOperationID == intent.operationID else {
            throw CloudDeletionError.invalidResponse
        }
        journal.deletionOperationID = intent.operationID
        if case .complete = status { journal.deletionCompleted = true }
        state.journalData = try JSONEncoder().encode(journal)
        // Fence as soon as the server accepts deletion, not only after cleanup.
        // Preserve the original binding and every local business/photo record.
        state.cloudDeleted = true
        try context.save()
    }

    func retainedDeletion() throws -> (operationID: UUID, completed: Bool)? {
        let context = ModelContext(container)
        guard let state = try Self.state(in: context), state.cloudDeleted else { return nil }
        guard let data = state.journalData else { throw CloudDeletionError.invalidResponse }
        let journal = try JSONDecoder().decode(SyncJournal.self, from: data)
        guard let operationID = journal.deletionOperationID else { throw CloudDeletionError.invalidResponse }
        return (operationID, journal.deletionCompleted == true)
    }

    func isBound(to intent: CloudDeletionIntent) throws -> Bool {
        let context = ModelContext(container)
        guard let state = try Self.state(in: context), let data = state.journalData else { return false }
        let journal = try JSONDecoder().decode(SyncJournal.self, from: data)
        return journal.accountID == intent.accountID && journal.workspaceID == intent.workspaceID
    }

    @discardableResult
    func receive(_ transaction: SyncRemoteTransaction) throws -> Bool {
        let context = ModelContext(container)
        var journal = try Self.read(in: context)
        var original = journal
        let current = try SyncGraphCodec.capture(in: context)
        let merged = try journal.receive(transaction, current: current)
        do {
            // Read committed data independently, but apply through the app's
            // context so open screens keep their existing, updated objects.
            try SyncGraphCodec.apply(merged, in: container.mainContext, journal: journal)
            return !current.contains(where: { $0.kind == .businessProfile }) &&
                merged.contains(where: { $0.kind == .businessProfile })
        } catch {
            if let graphError = error as? SyncGraphError, graphError == .unsavedChanges {
                throw error
            }
            guard error is DomainGraphViolation || error is SyncGraphError else { throw error }
            context.rollback()
            original.deferredRemote = transaction
            try Self.write(original, in: context)
            try context.save()
            throw SyncJournalError.unresolvedConflicts
        }
    }

    static func read(in context: ModelContext) throws -> SyncJournal {
        guard let state = try state(in: context), let data = state.journalData else {
            throw SyncJournalStoreError.unbound
        }
        guard !state.cloudDeleted else { throw SyncJournalStoreError.cloudAccountDeleted }
        return try JSONDecoder().decode(SyncJournal.self, from: data)
    }

    /// Does not save: remote graph changes and cursor advancement share a commit.
    static func write(_ journal: SyncJournal, in context: ModelContext) throws {
        guard let state = try state(in: context) else {
            throw SyncJournalStoreError.unbound
        }
        guard !state.cloudDeleted else { throw SyncJournalStoreError.cloudAccountDeleted }
        if let data = state.journalData {
            let existing = try JSONDecoder().decode(SyncJournal.self, from: data)
            try existing.verifyBinding(
                accountID: journal.accountID, workspaceID: journal.workspaceID
            )
            for archive in existing.invoiceHistoryArchives {
                guard journal.invoiceHistoryArchives.first(where: { $0.id == archive.id }) == archive else {
                    throw InvoiceHistoryError.immutableArchive
                }
            }
            for archive in journal.invoiceHistoryArchives where
                !existing.invoiceHistoryArchives.contains(where: { $0.id == archive.id }) {
                try journal.verifyBinding(accountID: archive.accountID, workspaceID: archive.workspaceID)
                try archive.validate()
            }
        }
        state.journalData = try JSONEncoder().encode(journal)
    }

    private static func state(in context: ModelContext) throws -> FarrierFlowSchemaV5.SyncState? {
        let states = try context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>())
        guard states.count <= 1 else { throw SyncJournalStoreError.duplicateState }
        return states.first
    }
}
