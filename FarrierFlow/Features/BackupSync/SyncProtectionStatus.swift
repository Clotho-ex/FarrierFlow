import Foundation

nonisolated struct SyncProtectionStatus: Equatable, Sendable {
    let recordCount: Int
    let protectedRecordCount: Int
    let pendingRecordCount: Int
    let photoCount: Int
    let protectedPhotoCount: Int
    let pendingPhotoDeletionCount: Int
    let conflictCount: Int
    let localOnlyInvoiceCount: Int
    let pendingBillingHoldCount: Int
    let lastRecordSync: Date?
    let lastPhotographCheck: Date?
    let isFullyProtected: Bool
    let isActiveDataProtected: Bool

    static func make(current: [SyncRecord], journal: SyncJournal?) throws -> Self {
        let local = try SyncJournal.index(current)
        let baseline = try SyncJournal.index(journal?.baseline ?? [])
        var pending = Set(local.keys).union(baseline.keys).filter { local[$0] != baseline[$0] }
        if let batch = journal?.pending {
            pending.formUnion(batch.mutations.filter { $0.record != baseline[$0.id] }.map(\.id))
        }
        let protectedRecords = current.filter { baseline[$0.id] == $0 }.count
        let photos = current.filter { $0.kind == .photograph }
        var receipts: [UUID: SyncPhotoManifestEntry] = [:]
        for receipt in journal?.verifiedPhotoReceipts ?? [] {
            guard receipt.isValid, receipts.updateValue(receipt, forKey: receipt.id) == nil else {
                throw SyncTransportError.invalidResponse
            }
        }
        let protectedPhotos = photos.filter {
            baseline[$0.id] == $0 && receipts[$0.id] != nil &&
            $0.fields["byteCount"] == receipts[$0.id].map { .integer($0.byteCount) }
        }.count
        let deletions = journal?.pendingPhotoDeletionIDs.count ?? 0
        let conflicts = (journal?.conflicts.count ?? 0) + (journal?.deferredRemote == nil ? 0 : 1) +
            (journal?.confirmedRejection == nil ? 0 : 1)
        let historyCount = journal?.invoiceHistoryArchives.reduce(0) { $0 + $1.invoiceIDs.count } ?? 0
        let pendingHolds = current.filter { $0.kind == .workItem &&
            $0.fields["billingHoldID"] != nil && $0.fields["billingHoldID"] != .null &&
            baseline[$0.id]?.fields["billingHoldID"] != $0.fields["billingHoldID"] }.count
        let activeProtected = journal?.lastSuccessfulSync != nil && journal?.pending == nil &&
            pending.isEmpty && protectedPhotos == photos.count && deletions == 0 && conflicts == 0
        return Self(
            recordCount: current.count, protectedRecordCount: protectedRecords,
            pendingRecordCount: pending.count, photoCount: photos.count,
            protectedPhotoCount: protectedPhotos, pendingPhotoDeletionCount: deletions,
            conflictCount: conflicts, localOnlyInvoiceCount: historyCount, pendingBillingHoldCount: pendingHolds,
            lastRecordSync: journal?.lastSuccessfulSync,
            lastPhotographCheck: journal?.lastPhotographCheck,
            isFullyProtected: activeProtected && historyCount == 0,
            isActiveDataProtected: activeProtected
        )
    }
}
