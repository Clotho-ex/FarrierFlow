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

    private func decodedArchives() throws -> [InvoiceHistoryArchive] {
        let context = ModelContext(container)
        let states = try context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>())
        guard states.count <= 1 else { throw SyncJournalStoreError.duplicateState }
        guard let state = states.first else { return [] }
        guard let data = state.journalData else {
            if state.cloudDeleted { throw InvoiceHistoryError.invalidArchive }
            return []
        }
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
