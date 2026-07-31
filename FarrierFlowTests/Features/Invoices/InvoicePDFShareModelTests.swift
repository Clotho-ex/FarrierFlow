import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice PDF share model", .serialized)
@MainActor
struct InvoicePDFShareModelTests {
    @Test func failureClearsStatePreservesInvoiceAndAllowsRetry() throws {
        let graph = try makeGraph()
        let parent = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-PDF-Share-"
        )
        let outputDirectory = parent.appending(path: "output")
        try Data("not a directory".utf8).write(to: outputDirectory)
        let model = InvoicePDFShareModel(
            store: InvoicePDFTemporaryFileStore(directory: outputDirectory)
        )
        let originalInvoice = try InvoicePDFContentBuilder.build(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        model.prepare(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        #expect(!model.isPreparing)
        #expect(model.alert != nil)
        #expect(model.shareURL == nil)
        #expect(!graph.context.hasChanges)
        #expect(try InvoicePDFContentBuilder.build(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        ) == originalInvoice)

        try FileManager.default.removeItem(at: outputDirectory)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        model.retry(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        let retryURL = try #require(model.shareURL)
        #expect(model.alert == nil)
        #expect(!model.isPreparing)
        #expect(retryURL.lastPathComponent == "Invoice-0001.pdf")
        #expect(FileManager.default.fileExists(atPath: retryURL.path))
    }

    @Test func failureDoesNotRetainStaleShareURL() throws {
        let graph = try makeGraph()
        let parent = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-PDF-Stale-"
        )
        let outputDirectory = parent.appending(path: "output")
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let model = InvoicePDFShareModel(
            store: InvoicePDFTemporaryFileStore(directory: outputDirectory)
        )
        model.prepare(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )
        let firstURL = try #require(model.shareURL)

        try FileManager.default.removeItem(at: firstURL)
        try FileManager.default.removeItem(at: outputDirectory)
        try Data("not a directory".utf8).write(to: outputDirectory)
        model.prepare(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )

        #expect(model.shareURL == nil)
        #expect(model.alert != nil)
        #expect(!model.isPreparing)
    }

    @Test func duplicateCleanupIsHarmlessAndSecondShareSucceeds() throws {
        let graph = try makeGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-PDF-Second-Share-"
        )
        let model = InvoicePDFShareModel(
            store: InvoicePDFTemporaryFileStore(directory: directory)
        )
        model.prepare(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )
        let firstURL = try #require(model.shareURL)

        model.sharingCompleted()
        model.sharingCompleted()

        #expect(model.shareURL == nil)
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))

        model.prepare(
            invoiceID: graph.invoice.persistentModelID,
            in: graph.context
        )
        let secondURL = try #require(model.shareURL)

        #expect(secondURL.lastPathComponent == "Invoice-0001.pdf")
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
    }

    private func makeGraph() throws -> ShareGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let profile = ModelFixtures.makeBusinessProfile(
            name: "Carter Farrier Service",
            nextInvoiceNumber: 2,
            in: context
        )
        let service = ModelFixtures.makeService(name: "Trim", in: context)
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [horse],
                in: context
            ),
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: context
        )
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: client,
            businessProfile: profile,
            in: context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem,
            in: context
        )
        try DomainGraphValidator.save(context)
        return ShareGraph(
            container: container,
            context: context,
            invoice: invoice
        )
    }
}

private struct ShareGraph {
    let container: ModelContainer
    let context: ModelContext
    let invoice: Invoice
}
