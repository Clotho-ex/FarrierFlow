import Foundation
import SwiftData

nonisolated enum SyncRecoverySettingsChoice: Hashable, Sendable { case keepLocal, useCloud }
nonisolated enum SyncInvoiceRecoveryError: Error, Equatable {
    case changedSinceReview, incompatibleGraph, nothingToRecover
}

nonisolated struct SyncRecoveryCloudSnapshot: Equatable, Sendable {
    let workspaceID: UUID
    let revision: Int64
    let records: [SyncRecord]
    let revisions: [UUID: Int64]
    let invoicingDeviceID: UUID?
    let invoicingGeneration: Int64
    var deletedPhotoIDs: Set<UUID> = []
}

nonisolated struct SyncInvoiceRecoveryReview: Equatable, Sendable {
    let current: [SyncRecord]
    let journal: SyncJournal
    let cloud: SyncRecoveryCloudSnapshot
    let archive: InvoiceHistoryArchive?
    let localProfile: SyncRecord
    let cloudProfile: SyncRecord

    @MainActor
    static func make(current: [SyncRecord], journal: SyncJournal,
                     cloud: SyncRecoveryCloudSnapshot, capturedAt: Date) throws -> Self {
        guard cloud.workspaceID == journal.workspaceID else { throw SyncJournalError.accountMismatch }
        guard cloud.revision >= journal.cursor, cloud.invoicingGeneration > 0,
              cloud.revisions.values.allSatisfy({ $0 > 0 && $0 <= cloud.revision }) else {
            throw SyncTransportError.invalidResponse
        }
        if let pending = journal.pending {
            guard let rejection = journal.confirmedRejection, rejection.batch == pending,
                  rejection.protocolVersion == journal.pendingProtocol else { throw SyncJournalError.pendingUpload }
        }
        let remote = try SyncJournal.index(cloud.records)
        guard let localProfile = current.first(where: { $0.kind == .businessProfile }),
              let cloudProfile = cloud.records.first(where: { $0.kind == .businessProfile }),
              localProfile.fields["currencyCode"] == cloudProfile.fields["currencyCode"],
              cloud.records.allSatisfy({ cloud.revisions[$0.id] != nil }) else {
            throw SyncInvoiceRecoveryError.incompatibleGraph
        }
        for graph in [current, cloud.records] {
            _ = try SyncGraphCodec.readOnlyGraph(graph)
        }
        let protected = Set(journal.baseline.filter { $0.kind == .invoice }.map(\.id))
        let cloudNumbers = Set(cloud.records.filter { $0.kind == .invoice }.compactMap { record -> Int64? in
            guard case .integer(let number) = record.fields["number"] else { return nil }
            return number
        })
        let billedWork = Set(cloud.records.filter { $0.kind == .invoiceLineItem }
            .compactMap { reference($0.fields["sourceWorkItem"]) })
            .union(cloud.records.filter { $0.kind == .workItem && $0.fields["billingHoldID"] != nil &&
                $0.fields["billingHoldID"] != .null }.map(\.id))
        let staleAuthority = cloud.invoicingDeviceID != journal.deviceID ||
            journal.confirmedRejection?.reason == .invoicingAuthority
        var selected: [UUID] = []
        for invoice in current where invoice.kind == .invoice && remote[invoice.id] == nil && !protected.contains(invoice.id) {
            let groups = Set(current.filter { $0.kind == .invoiceVisit && reference($0.fields["invoice"]) == invoice.id }.map(\.id))
            let source = Set(current.filter { $0.kind == .invoiceLineItem &&
                reference($0.fields["invoiceVisit"]).map(groups.contains) == true }
                .compactMap { reference($0.fields["sourceWorkItem"]) })
            let collides: Bool
            if case .integer(let number) = invoice.fields["number"] { collides = cloudNumbers.contains(number) }
            else { throw SyncInvoiceRecoveryError.incompatibleGraph }
            if staleAuthority || collides ||
                !source.isDisjoint(with: billedWork) { selected.append(invoice.id) }
        }
        let archive: InvoiceHistoryArchive?
        if selected.isEmpty { archive = nil }
        else {
            let reason: InvoiceHistoryReason = staleAuthority ? .staleInvoicingAuthority :
                (journal.confirmedRejection?.reason == .alreadyBilled ? .alreadyBilled : .numberCollision)
            archive = try InvoiceHistoryArchive(accountID: journal.accountID, workspaceID: journal.workspaceID,
                capturedAt: capturedAt, reason: reason, sourceOperationID: journal.pending?.operationID,
                records: current, invoiceIDs: selected)
        }
        guard archive != nil || localProfile.id != cloudProfile.id || journal.confirmedRejection != nil else {
            throw SyncInvoiceRecoveryError.nothingToRecover
        }
        let review = Self(current: current, journal: journal, cloud: cloud, archive: archive,
            localProfile: localProfile, cloudProfile: cloudProfile)
        _ = try review.resolved(settings: .useCloud)
        return review
    }

    private var archivedRecordIDs: Set<UUID> {
        let invoices = Set(archive?.invoiceIDs ?? [])
        let groups = Set(current.filter { $0.kind == .invoiceVisit &&
            Self.reference($0.fields["invoice"]).map(invoices.contains) == true }.map(\.id))
        return Set(current.filter { record in
            invoices.contains(record.id) || groups.contains(record.id) ||
                (record.kind == .invoiceLineItem && Self.reference(record.fields["invoiceVisit"]).map(groups.contains) == true) ||
                (record.kind == .payment && Self.reference(record.fields["invoice"]).map(invoices.contains) == true)
        }.map(\.id))
    }

    var resolvedConflictIDs: Set<UUID> {
        archivedRecordIDs.union([localProfile.id, cloudProfile.id])
    }

    @MainActor
    func resolved(settings: SyncRecoverySettingsChoice) throws -> [SyncRecord] {
        let local = try SyncJournal.index(current), remote = try SyncJournal.index(cloud.records)
        let base = try SyncJournal.index(journal.baseline)
        let removed = archivedRecordIDs
        let unresolved = Set(journal.conflicts.map(\.id)).subtracting(resolvedConflictIDs)
        var combined: [UUID: SyncRecord] = [:]
        for id in Set(local.keys).union(remote.keys) {
            if removed.contains(id) || id == localProfile.id || id == cloudProfile.id { continue }
            let l = local[id], r = remote[id]
            // Invoice/settings confirmation does not choose a version of an
            // unrelated conflicted record. Keep it intact for conflict review.
            if unresolved.contains(id) { combined[id] = l; continue }
            if r == nil, cloud.revisions[id] != nil, l != nil, base[id] == nil {
                throw SyncInvoiceRecoveryError.incompatibleGraph
            }
            switch SyncRecordMerge.merge(base: Self.canonical(base[id]),
                local: Self.canonical(l), remote: Self.canonical(r)) {
            case .merged(let record): combined[id] = record
            case .conflict: throw SyncInvoiceRecoveryError.incompatibleGraph
            }
        }
        for (invoice, workIDs) in archive?.sourceWorkItemIDs ?? [:] {
            for workID in workIDs {
                guard let work = combined[workID] else { continue }
                var fields = work.fields
                if fields["billingHoldID"] == nil || fields["billingHoldID"] == .null {
                    fields["billingHoldID"] = .string(invoice.uuidString.lowercased())
                }
                combined[workID] = SyncRecord(id: work.id, kind: work.kind, fields: fields)
            }
        }
        var profile = settings == .keepLocal ? localProfile.fields : cloudProfile.fields
        profile["nextInvoiceNumber"] = cloudProfile.fields["nextInvoiceNumber"]
        if cloud.invoicingDeviceID == journal.deviceID &&
            cloud.invoicingGeneration == journal.invoicingGeneration &&
            journal.confirmedRejection?.reason != .invoicingAuthority {
            guard case .integer(let cloudNext) = cloudProfile.fields["nextInvoiceNumber"],
                  case .integer(let localNext) = localProfile.fields["nextInvoiceNumber"] else {
                throw SyncInvoiceRecoveryError.incompatibleGraph
            }
            profile["nextInvoiceNumber"] = .integer(max(cloudNext, localNext))
        }
        combined[cloudProfile.id] = SyncRecord(id: cloudProfile.id, kind: .businessProfile, fields: profile)
        let result = combined.values.sorted { $0.id.uuidString < $1.id.uuidString }
        _ = try SyncGraphCodec.readOnlyGraph(result)
        return result
    }

    private static func reference(_ value: SyncValue?) -> UUID? {
        guard case .string(let value) = value else { return nil }
        return UUID(uuidString: value)
    }

    private static func canonical(_ record: SyncRecord?) -> SyncRecord? {
        guard let record, record.kind == .workItem, record.fields["billingHoldID"] == nil else { return record }
        var fields = record.fields
        fields["billingHoldID"] = .null
        return SyncRecord(id: record.id, kind: record.kind, fields: fields)
    }
}
