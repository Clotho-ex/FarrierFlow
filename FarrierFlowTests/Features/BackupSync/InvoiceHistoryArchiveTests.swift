import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Local invoice history archive", .serialized)
@MainActor
struct InvoiceHistoryArchiveTests {
    @Test(arguments: [InvoiceStatus.unpaid, .paid])
    func archiveRoundTripsPaidAndUnpaidExactHistory(status: InvoiceStatus) throws {
        let f = try fixture(status: status)
        try f.store.update { try $0.addArchive(f.archive) }
        let stored = try #require(try f.store.journal()?.invoiceHistoryArchives.first)
        #expect(stored == f.archive)
        let reader = InvoiceHistoryArchiveReader(container: f.graph.container)
        let content = try reader.content(archiveID: stored.id, invoiceID: f.invoiceID)
        #expect(content.number == "0001" && content.currencyCode == "GBP")
        #expect(content.totalMinorUnits == 12_500 && content.status == status)
        #expect(content.payment?.amountMinorUnits == (status == .paid ? 12_500 : nil))
        #expect(content.visits.first?.lineItems.first?.horseName == "Milo")
        let batch = try #require(try f.store.stage())
        #expect(batch.mutations.count == f.archive.records.count)
        #expect(!String(decoding: try JSONEncoder().encode(batch), as: UTF8.self).contains("invoiceHistory"))
    }

    @Test
    func countingLocalHistoryDoesNotRebuildArchivedGraphs() throws {
        let f = try fixture(status: .paid)
        try f.store.update { try $0.addArchive(f.archive) }
        let reader = InvoiceHistoryArchiveReader(container: f.graph.container, makeGraph: { _ in
            throw UnexpectedGraphRebuild.expected
        })
        #expect(try reader.invoiceCount() == 1)
        #expect(try reader.invoiceCount() == 1)
        #expect(throws: UnexpectedGraphRebuild.expected) { try reader.content(archiveID: f.archive.id, invoiceID: f.invoiceID) }
    }

    @Test
    func archiveCannotBeReplaced() throws {
        let f = try fixture(status: .unpaid)
        try f.store.update { try $0.addArchive(f.archive) }
        let changed = try InvoiceHistoryArchive(id: f.archive.id, accountID: f.account,
            workspaceID: f.workspace, capturedAt: Date(timeIntervalSinceReferenceDate: 999),
            reason: .numberCollision, sourceOperationID: nil,
            records: f.archive.records, invoiceIDs: [f.invoiceID])
        #expect(throws: (any Error).self) { try f.store.update { try $0.addArchive(changed) } }
        #expect(try f.store.journal()?.invoiceHistoryArchives == [f.archive])
    }

    @Test
    func readerWorksSignedOutAndAfterCloudDeletion() throws {
        let f = try fixture(status: .paid)
        try f.store.update { try $0.addArchive(f.archive) }
        let deletion = try CloudDeletionIntent(accountID: f.account, workspaceID: f.workspace)
        try f.store.recordCloudDeletion(deletion, status: .complete(deletion.operationID))
        #expect(throws: SyncJournalStoreError.cloudAccountDeleted) { try f.store.journal() }
        let reader = InvoiceHistoryArchiveReader(container: f.graph.container)
        #expect(try reader.archives() == [f.archive])
        #expect(try reader.invoiceCount() == 1)
        #expect(try reader.content(archiveID: f.archive.id, invoiceID: f.invoiceID).totalMinorUnits == 12_500)
        #expect(try f.store.retainedDeletion()?.completed == true)
    }

    @Test
    func unknownOrCorruptArchiveFailsWithoutChangingStoredBytes() throws {
        let f = try fixture(status: .unpaid)
        try f.store.update { try $0.addArchive(f.archive) }
        let context = ModelContext(f.graph.container)
        let state = try #require(context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first)
        let data = try #require(state.journalData)
        let text = String(decoding: data, as: UTF8.self)
        let invalid = Data(text.replacingOccurrences(of: "\"version\":1", with: "\"version\":99").utf8)
        #expect(invalid != data)
        state.journalData = invalid
        try context.save()
        #expect(throws: (any Error).self) {
            try InvoiceHistoryArchiveReader(container: f.graph.container).archives()
        }
        #expect(throws: (any Error).self) {
            try InvoiceHistoryArchiveReader(container: f.graph.container).invoiceCount()
        }
        #expect(try ModelContext(f.graph.container)
            .fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first?.journalData == invalid)
    }

    @Test(arguments: ["version", "account", "duplicateInvoice"])
    func countRejectsInvalidArchiveHeaders(corruption: String) throws {
        let f = try fixture(status: .unpaid)
        try f.store.update { try $0.addArchive(f.archive) }
        let context = ModelContext(f.graph.container)
        let state = try #require(context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first)
        let data = try #require(state.journalData)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var archives = try #require(object["invoiceHistory"] as? [[String: Any]])
        switch corruption {
        case "version": archives[0]["version"] = 99
        case "account": archives[0]["accountID"] = UUID().uuidString
        default: archives[0]["invoiceIDs"] = [f.invoiceID.uuidString, f.invoiceID.uuidString]
        }
        object["invoiceHistory"] = archives
        state.journalData = try JSONSerialization.data(withJSONObject: object)
        try context.save()
        #expect(throws: (any Error).self) {
            try InvoiceHistoryArchiveReader(container: f.graph.container).invoiceCount()
        }
    }

    @Test
    func countingHeadersDoesNotBypassValidationWhenFinancialHistoryIsOpened() throws {
        let f = try fixture(status: .unpaid)
        try f.store.update { try $0.addArchive(f.archive) }
        let context = ModelContext(f.graph.container)
        let state = try #require(context.fetch(FetchDescriptor<FarrierFlowSchemaV5.SyncState>()).first)
        let data = try #require(state.journalData)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var archives = try #require(object["invoiceHistory"] as? [[String: Any]])
        var records = try #require(archives[0]["records"] as? [[String: Any]])
        let index = try #require(records.firstIndex { $0["kind"] as? String == "invoiceLineItem" })
        var fields = try #require(records[index]["fields"] as? [String: Any])
        fields["amountMinorUnits"] = -1
        records[index]["fields"] = fields
        archives[0]["records"] = records
        object["invoiceHistory"] = archives
        state.journalData = try JSONSerialization.data(withJSONObject: object)
        try context.save()
        let reader = InvoiceHistoryArchiveReader(container: f.graph.container)
        #expect(try reader.invoiceCount() == 1)
        #expect(throws: (any Error).self) { try reader.content(archiveID: f.archive.id, invoiceID: f.invoiceID) }
    }

    private enum UnexpectedGraphRebuild: Error { case expected }

    private func fixture(status: InvoiceStatus) throws -> (
        graph: InvoiceActionGraph, store: SyncJournalStore, account: UUID,
        workspace: UUID, invoiceID: UUID, archive: InvoiceHistoryArchive
    ) {
        let graph = try InvoiceActionGraph.make(status: status, currencyCode: "GBP")
        let account = UUID(), workspace = UUID()
        let store = SyncJournalStore(container: graph.container)
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        let invoiceID = try #require(invoice.syncID)
        let records = try SyncGraphCodec.capture(in: graph.context)
        let archive = try InvoiceHistoryArchive(accountID: account, workspaceID: workspace,
            capturedAt: Date(timeIntervalSinceReferenceDate: 700), reason: .numberCollision,
            sourceOperationID: nil, records: records, invoiceIDs: [invoiceID])
        return (graph, store, account, workspace, invoiceID, archive)
    }
}
