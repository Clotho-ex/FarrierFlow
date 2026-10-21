import Foundation
import SwiftData

@MainActor
struct InvoiceHistoryArchiveReader {
    let container: ModelContainer
    var makeGraph: @MainActor ([SyncRecord]) throws -> ModelContainer = SyncGraphCodec.readOnlyGraph

    func archives() throws -> [InvoiceHistoryArchive] {
        let archives = try decodedArchives()
        for archive in archives { _ = try makeGraph(archive.records) }
        return archives
    }

    /// Count validated headers without decoding/projecting every financial
    /// record. Opening history still validates the complete archived graph.
    func invoiceCount() throws -> Int {
        guard let data = try journalData() else { return 0 }
        let journal = try JSONDecoder().decode(CountJournal.self, from: data)
        var seen: Set<UUID> = []
        var count = 0
        for archive in journal.invoiceHistory ?? [] {
            guard archive.version == 1 else { throw InvoiceHistoryError.unsupportedVersion }
            guard seen.insert(archive.id).inserted,
                  archive.accountID == journal.accountID, archive.workspaceID == journal.workspaceID,
                  archive.capturedAt.timeIntervalSinceReferenceDate.isFinite,
                  !archive.invoiceIDs.isEmpty, Set(archive.invoiceIDs).count == archive.invoiceIDs.count,
                  Set(archive.sourceWorkItemIDs.keys) == Set(archive.invoiceIDs),
                  archive.sourceWorkItemIDs.values.allSatisfy({ Set($0).count == $0.count }) else {
                throw InvoiceHistoryError.invalidArchive
            }
            count += archive.invoiceIDs.count
        }
        return count
    }

    private struct CountJournal: Decodable {
        let accountID: UUID
        let workspaceID: UUID
        let invoiceHistory: [CountArchive]?
    }

    private struct CountArchive: Decodable {
        let version: Int
        let id: UUID
        let accountID: UUID
        let workspaceID: UUID
        let capturedAt: Date
        let reason: InvoiceHistoryReason
        let sourceOperationID: UUID?
        let invoiceIDs: [UUID]
        let sourceWorkItemIDs: [UUID: [UUID]]
    }

    private func journalData() throws -> Data? {
        let context = ModelContext(container)
        let states = try context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>())
        guard states.count <= 1 else { throw SyncJournalStoreError.duplicateState }
        guard let state = states.first else { return nil }
        guard let data = state.journalData else {
            if state.cloudDeleted { throw InvoiceHistoryError.invalidArchive }
            return nil
        }
        return data
    }

    private func decodedArchives() throws -> [InvoiceHistoryArchive] {
        guard let data = try journalData() else { return [] }
        // Local financial access does not depend on an active cloud account.
        // The retained binding and deletion fence are never changed here.
        let journal = try JSONDecoder().decode(SyncJournal.self, from: data)
        let archives = journal.invoiceHistoryArchives
        guard Set(archives.map(\.id)).count == archives.count else {
            throw InvoiceHistoryError.invalidArchive
        }
        for archive in archives {
            try journal.verifyBinding(accountID: archive.accountID, workspaceID: archive.workspaceID)
            try archive.validateMetadata()
        }
        return archives
    }

    func summaries() throws -> [InvoiceHistorySummary] {
        try decodedArchives().flatMap { archive in
            let isolated = try makeGraph(archive.records)
            let invoices = try isolated.mainContext.fetch(FetchDescriptor<Invoice>())
            return try archive.invoiceIDs.map { id in
                guard let invoice = invoices.first(where: { $0.syncID == id }) else {
                    throw InvoiceHistoryError.invoiceUnavailable
                }
                return InvoiceHistorySummary(id: .init(archiveID: archive.id, invoiceID: id),
                    capturedAt: archive.capturedAt, reason: archive.reason,
                    content: try InvoicePDFContentBuilder.build(invoice: invoice))
            }
        }
    }

    func content(archiveID: UUID, invoiceID: UUID) throws -> InvoicePDFContent {
        guard let archive = try decodedArchives().first(where: { $0.id == archiveID }),
              archive.invoiceIDs.contains(invoiceID) else {
            throw InvoiceHistoryError.invoiceUnavailable
        }
        let isolated = try makeGraph(archive.records)
        guard let invoice = try isolated.mainContext.fetch(FetchDescriptor<Invoice>())
            .first(where: { $0.syncID == invoiceID }) else {
            throw InvoiceHistoryError.invoiceUnavailable
        }
        return try InvoicePDFContentBuilder.build(invoice: invoice)
    }
}
