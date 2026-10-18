import Foundation
import Combine
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Read-only invoice history presentation", .serialized)
@MainActor
struct InvoiceHistoryModelTests {
    @Test
    func eachArchiveIsProjectedOnceAndDetailOnlyProjectsItsArchive() throws {
        let f = try fixture()
        var projections = 0
        let reader = InvoiceHistoryArchiveReader(container: f.container, makeGraph: { records in
            projections += 1
            return try SyncGraphCodec.readOnlyGraph(records)
        })
        let summaries = try reader.summaries()
        #expect(summaries.count == 2 && projections == 2)
        let selected = try #require(summaries.first)
        projections = 0
        #expect(try reader.content(archiveID: selected.id.archiveID,
            invoiceID: selected.id.invoiceID) == selected.content)
        #expect(projections == 1)
    }

    @Test
    func readingHistoryNeverPublishesTemporaryStoreSaves() throws {
        let f = try fixture()
        let projection = try SyncGraphCodec.readOnlyGraph(f.archive.records)
        #expect(!projection.mainContext.autosaveEnabled)
        var saves = 0
        let observer = NotificationCenter.default.publisher(for: ModelContext.didSave)
            .sink { _ in MainActor.assumeIsolated { saves += 1 } }
        defer { observer.cancel() }
        let model = InvoiceHistoryModel(container: f.container)
        try model.load()
        #expect(!model.summaries.isEmpty)
        #expect(saves == 0)
    }
    @Test
    func cancellationDuringRenderingCleansFilesAndPreservesHistory() async throws {
        let f = try fixture()
        let gate = DispatchSemaphore(value: 0)
        let (events, continuation) = AsyncStream<Void>.makeStream()
        let model = InvoiceHistoryModel(container: f.container, writer: .init { content in
            continuation.yield()
            gate.wait()
            return try InvoicePDFRenderer().render(content)
        })
        try model.load()
        let invoice = try #require(model.summaries.first)
        let preparation = Task { await model.preparePDF(archiveID: invoice.id.archiveID, invoiceID: invoice.id.invoiceID) }
        var iterator = events.makeAsyncIterator()
        _ = await iterator.next()
        #expect(model.isPreparing)
        let prefixes = try FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory,
            includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("FarrierFlow-History-\(invoice.id.archiveID)-\(invoice.id.invoiceID)-") }
        #expect(prefixes.count == 1)
        preparation.cancel()
        gate.signal()
        await preparation.value
        #expect(!model.isPreparing && model.shareURL == nil && model.alert == nil)
        #expect(prefixes.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(try InvoiceHistoryArchiveReader(container: f.container).archives().count == 2)
    }
    @Test
    func duplicateNumbersUseIndependentExportsWithoutSessionOrPro() async throws {
        let f = try fixture()
        let first = InvoiceHistoryModel(container: f.container)
        let second = InvoiceHistoryModel(container: f.container)
        try first.load()
        #expect(first.summaries.count == 2)
        let a = try #require(first.summaries.first), b = try #require(first.summaries.last)
        #expect(a.content.number == b.content.number && a.id != b.id)
        await first.preparePDF(archiveID: a.id.archiveID, invoiceID: a.id.invoiceID)
        await second.preparePDF(archiveID: b.id.archiveID, invoiceID: b.id.invoiceID)
        let urlA = try #require(first.shareURL), urlB = try #require(second.shareURL)
        #expect(urlA != urlB && urlA.lastPathComponent == "Invoice-0001.pdf")
        #expect(try Data(contentsOf: urlA).starts(with: Data("%PDF".utf8)))
        first.sharingCompleted()
        #expect(!FileManager.default.fileExists(atPath: urlA.path))
        #expect(FileManager.default.fileExists(atPath: urlB.path))
        second.sharingCompleted()
        #expect(!FileManager.default.fileExists(atPath: urlB.deletingLastPathComponent().path))
    }

    @Test
    func failedExportRetainsOriginalHistoryAndLeavesNoShareFile() async throws {
        let f = try fixture()
        let model = InvoiceHistoryModel(container: f.container,
            writer: InvoicePDFDocumentWriter(render: { _ in throw InvoiceHistoryError.invalidArchive }))
        try model.load()
        let summary = try #require(model.summaries.first)
        await model.preparePDF(archiveID: summary.id.archiveID, invoiceID: summary.id.invoiceID)
        #expect(model.shareURL == nil && model.alert != nil && !model.isPreparing)
        #expect(try InvoiceHistoryArchiveReader(container: f.container).archives().count == 2)
    }

    @Test
    func localHistoryPreventsWholeBusinessProtectionAfterHoldAcknowledgment() throws {
        let f = try fixture()
        let store = SyncJournalStore(container: f.container)
        let work = try #require(f.container.mainContext.fetch(FetchDescriptor<WorkItem>()).first)
        let invoice = try #require(f.container.mainContext.fetch(FetchDescriptor<Invoice>()).first)
        try work.applyBillingHold(#require(invoice.syncID))
        try f.container.mainContext.save()
        let current = try SyncGraphCodec.capture(in: f.container.mainContext)
        var journal = try #require(try store.journal())
        let before = try SyncProtectionStatus.make(current: current, journal: journal)
        #expect(before.localOnlyInvoiceCount == 2 && before.pendingBillingHoldCount == 1)
        let batch = try #require(try journal.stage(current))
        try journal.acknowledge(operationID: batch.operationID, revision: 1)
        journal.lastSuccessfulSync = Date()
        let after = try SyncProtectionStatus.make(current: current, journal: journal)
        #expect(after.pendingBillingHoldCount == 0 && after.localOnlyInvoiceCount == 2)
        #expect(!after.isFullyProtected)
    }

    private func fixture() throws -> (container: ModelContainer, archive: InvoiceHistoryArchive) {
        let graph = try InvoiceActionGraph.make(status: .paid, currencyCode: "GBP")
        let store = SyncJournalStore(container: graph.container)
        let account = UUID(), workspace = UUID()
        try store.bind(accountID: account, workspaceID: workspace, deviceID: UUID())
        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        let archive = try InvoiceHistoryArchive(accountID: account, workspaceID: workspace,
            capturedAt: Date(), reason: .numberCollision, sourceOperationID: nil,
            records: SyncGraphCodec.capture(in: graph.context), invoiceIDs: [#require(invoice.syncID)])
        let other = try InvoiceActionGraph.make(status: .unpaid, currencyCode: "GBP")
        let otherInvoice = try #require(other.context.model(for: other.invoiceID) as? Invoice)
        let second = try InvoiceHistoryArchive(accountID: account, workspaceID: workspace,
            capturedAt: Date(), reason: .numberCollision, sourceOperationID: nil,
            records: SyncGraphCodec.capture(in: other.context), invoiceIDs: [#require(otherInvoice.syncID)])
        try store.update { try $0.addArchive(archive); try $0.addArchive(second) }
        return (graph.container, archive)
    }
}
