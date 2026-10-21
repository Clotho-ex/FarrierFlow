import Foundation
import Observation
import SwiftData

nonisolated enum SyncConflictChoice: String, Hashable, Sendable {
    case keepIPhone, useCloud
}

nonisolated enum SyncConflictResolutionError: Error, Equatable {
    case changedSinceReview, incompleteChoices, deletedIdentity
}

@MainActor
@Observable
final class SyncConflictModel {
    private let container: ModelContainer
    private let store: SyncJournalStore
    @ObservationIgnored private var reviewedGraph: [SyncRecord] = []
    @ObservationIgnored private var reviewedJournal: SyncJournal?
    @ObservationIgnored private var reviewedCloudGraph: [SyncRecord] = []
    private(set) var conflicts: [SyncConflict] = []
    private(set) var deferredRemote: SyncRemoteTransaction?
    private(set) var confirmedRejection: SyncConfirmedRejection?
    private(set) var relatedChanges: [SyncConflict] = []
    private(set) var needsInvoiceRecovery = false

    init(container: ModelContainer) {
        self.container = container
        store = SyncJournalStore(container: container)
    }

    func load(accountID: UUID) throws {
        guard let journal = try store.journal() else { throw SyncJournalStoreError.unbound }
        try journal.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
        let current = try SyncGraphCodec.capture(in: ModelContext(container))
        reviewedGraph = current
        reviewedJournal = journal
        deferredRemote = journal.deferredRemote
        confirmedRejection = journal.confirmedRejection
        needsInvoiceRecovery = confirmedRejection != nil
        var tentative = journal
        var localChoices = current
        if let transaction = deferredRemote {
            let merged = try tentative.receive(transaction, current: current)
            localChoices = merged
            let graph = try SyncJournal.index(current)
            if let localProfile = current.first(where: { $0.kind == .businessProfile }),
               let cloudProfile = tentative.baseline.first(where: { $0.kind == .businessProfile }),
               localProfile.id != cloudProfile.id { needsInvoiceRecovery = true }
            let numbers = merged.filter { $0.kind == .invoice }.compactMap { record -> Int64? in
                guard case .integer(let number) = record.fields["number"] else { return nil }
                return number
            }
            if Set(numbers).count != numbers.count { needsInvoiceRecovery = true }
            conflicts = tentative.conflicts
            if conflicts.isEmpty && !needsInvoiceRecovery {
                // A change can conflict with a newly created related record
                // without a same-UUID field conflict (for example a horse move
                // versus an offline appointment). Review the transaction's
                // changed records instead of misrouting it to invoice recovery.
                conflicts = transaction.mutations.filter { graph[$0.id] != $0.record }
                    .map { .init(id: $0.id, kind: $0.kind, local: graph[$0.id], remote: $0.record) }
            }
            relatedChanges = transaction.mutations.filter { mutation in
                !conflicts.contains(where: { $0.id == mutation.id }) && graph[mutation.id] != mutation.record
            }.map { .init(id: $0.id, kind: $0.kind, local: graph[$0.id], remote: $0.record) }
        } else { relatedChanges = []; conflicts = tentative.conflicts }
        let localByID = try SyncJournal.index(localChoices)
        conflicts = conflicts.map {
            SyncConflict(id: $0.id, kind: $0.kind, local: localByID[$0.id], remote: $0.remote,
                         unresolvedFields: $0.unresolvedFields)
        }
        reviewedCloudGraph = tentative.baseline
    }

    func resolve(_ choices: [UUID: SyncConflictChoice], accountID: UUID) throws {
        guard var journal = try store.journal() else { throw SyncJournalStoreError.unbound }
        try journal.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
        guard !container.mainContext.hasChanges else { throw SyncGraphError.unsavedChanges }
        let current = try SyncGraphCodec.capture(in: ModelContext(container))
        guard let reviewedJournal, reviewedJournal.accountID == accountID,
              reviewedJournal == journal, current == reviewedGraph else {
            throw SyncConflictResolutionError.changedSinceReview
        }
        guard !needsInvoiceRecovery else { throw SyncJournalError.unresolvedConflicts }
        let merged: [SyncRecord]
        if let transaction = journal.deferredRemote {
            merged = try journal.receive(transaction, current: current)
        } else { merged = current }
        let resolved: [SyncRecord]
        if journal.conflicts.isEmpty && deferredRemote != nil {
            guard Set(choices.keys) == Set(conflicts.map(\.id)) else {
                throw SyncConflictResolutionError.incompleteChoices
            }
            var records = try SyncJournal.index(merged)
            for conflict in conflicts {
                if choices[conflict.id] == .useCloud { records[conflict.id] = conflict.remote }
                else {
                    guard conflict.remote != nil else { throw SyncConflictResolutionError.deletedIdentity }
                    records[conflict.id] = conflict.local
                }
            }
            resolved = records.values.sorted { $0.id.uuidString < $1.id.uuidString }
        } else { resolved = try journal.resolveConflicts(choices, current: merged) }
        // Graph validation and journal save are one transaction. A dependency
        // conflict cannot clear the review queue while leaving a broken graph.
        try SyncGraphCodec.apply(resolved, in: container.mainContext, journal: journal)
        reviewedGraph = resolved
        self.reviewedJournal = journal
        conflicts = journal.conflicts
        deferredRemote = journal.deferredRemote
        relatedChanges = []
    }

    func changedFields(in conflict: SyncConflict) -> [String] {
        Set(conflict.local?.fields.keys.map { $0 } ?? [])
            .union(conflict.remote?.fields.keys.map { $0 } ?? [])
            .filter { conflict.local?.fields[$0] != conflict.remote?.fields[$0] }.sorted()
    }

    func value(in conflict: SyncConflict, field: String, cloud: Bool, locale: Locale) -> String {
        let record = cloud ? conflict.remote : conflict.local
        return SyncConflictPresentation.value(record?.fields[field], key: field, record: record,
            graph: cloud ? reviewedCloudGraph : reviewedGraph, locale: locale)
    }
}
