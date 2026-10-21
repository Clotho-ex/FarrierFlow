import Foundation
import SwiftData

nonisolated enum InvoiceHistoryReason: String, Codable, Sendable {
    case numberCollision, staleInvoicingAuthority, alreadyBilled
}

nonisolated enum InvoiceHistoryError: Error, Equatable {
    case invalidArchive, unsupportedVersion, immutableArchive, invoiceUnavailable
}

/// A self-contained financial snapshot. JPEG files are not copied into this data.
nonisolated struct InvoiceHistoryArchive: Codable, Equatable, Sendable, Identifiable {
    let version: Int
    let id: UUID
    let accountID: UUID
    let workspaceID: UUID
    let capturedAt: Date
    let reason: InvoiceHistoryReason
    let sourceOperationID: UUID?
    let records: [SyncRecord]
    let invoiceIDs: [UUID]
    let sourceWorkItemIDs: [UUID: [UUID]]

    init(id: UUID = UUID(), accountID: UUID, workspaceID: UUID, capturedAt: Date,
         reason: InvoiceHistoryReason, sourceOperationID: UUID?,
         records: [SyncRecord], invoiceIDs: [UUID]) throws {
        version = 1
        self.id = id
        self.accountID = accountID
        self.workspaceID = workspaceID
        self.capturedAt = capturedAt
        self.reason = reason
        self.sourceOperationID = sourceOperationID
        self.records = records
        self.invoiceIDs = invoiceIDs.sorted { $0.uuidString < $1.uuidString }
        sourceWorkItemIDs = try Self.workMapping(records: records, invoiceIDs: invoiceIDs)
    }

    @MainActor
    func validate() throws {
        try validateMetadata()
        _ = try SyncGraphCodec.readOnlyGraph(records)
    }

    func validateMetadata() throws {
        guard version == 1 else { throw InvoiceHistoryError.unsupportedVersion }
        guard capturedAt.timeIntervalSinceReferenceDate.isFinite,
              sourceWorkItemIDs == (try Self.workMapping(records: records, invoiceIDs: invoiceIDs)) else {
            throw InvoiceHistoryError.invalidArchive
        }
    }

    private static func workMapping(records: [SyncRecord], invoiceIDs: [UUID]) throws -> [UUID: [UUID]] {
        let graph = try SyncJournal.index(records)
        guard !invoiceIDs.isEmpty, Set(invoiceIDs).count == invoiceIDs.count else {
            throw InvoiceHistoryError.invalidArchive
        }
        var result: [UUID: [UUID]] = [:]
        for invoiceID in invoiceIDs {
            guard graph[invoiceID]?.kind == .invoice else { throw InvoiceHistoryError.invalidArchive }
            let groups = Set(records.filter {
                $0.kind == .invoiceVisit && $0.fields["invoice"] == .string(invoiceID.uuidString.lowercased())
            }.map(\.id))
            let work = try records.filter { record in
                guard record.kind == .invoiceLineItem,
                      case .string(let value) = record.fields["invoiceVisit"],
                      let id = UUID(uuidString: value) else { return false }
                return groups.contains(id)
            }.compactMap { record -> UUID? in
                if record.fields["sourceWorkItem"] == .null { return nil }
                guard case .string(let value) = record.fields["sourceWorkItem"],
                      let id = UUID(uuidString: value), graph[id]?.kind == .workItem else {
                    throw InvoiceHistoryError.invalidArchive
                }
                return id
            }
            guard !groups.isEmpty, Set(work).count == work.count else {
                throw InvoiceHistoryError.invalidArchive
            }
            result[invoiceID] = work.sorted { $0.uuidString < $1.uuidString }
        }
        return result
    }
}
