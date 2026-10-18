import Foundation
import Observation
import SwiftData

nonisolated struct InvoiceHistoryIdentity: Hashable, Sendable {
    let archiveID: UUID
    let invoiceID: UUID
}

nonisolated struct InvoiceHistorySummary: Identifiable, Equatable, Sendable {
    let id: InvoiceHistoryIdentity
    let capturedAt: Date
    let reason: InvoiceHistoryReason
    let content: InvoicePDFContent
}

@MainActor
@Observable
final class InvoiceHistoryModel {
    private let reader: InvoiceHistoryArchiveReader
    private let writer: InvoicePDFDocumentWriter
    private var exportDirectory: URL?
    private var generation = UUID()
    private(set) var summaries: [InvoiceHistorySummary] = []
    private(set) var isPreparing = false
    var shareURL: URL?
    var alert: FeatureAlert?

    init(container: ModelContainer, writer: InvoicePDFDocumentWriter = .init()) {
        reader = InvoiceHistoryArchiveReader(container: container)
        self.writer = writer
    }

    func load() throws {
        let result = try reader.summaries()
        summaries = result.sorted {
            if $0.content.invoiceDate != $1.content.invoiceDate { return $0.content.invoiceDate > $1.content.invoiceDate }
            if $0.id.archiveID != $1.id.archiveID { return $0.id.archiveID.uuidString < $1.id.archiveID.uuidString }
            return $0.id.invoiceID.uuidString < $1.id.invoiceID.uuidString
        }
    }

    func content(for identity: InvoiceHistoryIdentity) throws -> InvoicePDFContent {
        try reader.content(archiveID: identity.archiveID, invoiceID: identity.invoiceID)
    }

    func preparePDF(archiveID: UUID, invoiceID: UUID) async {
        guard !isPreparing else { return }
        sharingCompleted()
        let token = UUID()
        generation = token
        isPreparing = true
        alert = nil
        defer { isPreparing = false }
        // Each export owns a directory: duplicate printed numbers and another
        // history screen's cleanup must never overwrite a still-shared file.
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FarrierFlow-History-\(archiveID)-\(invoiceID)-\(token)")
        do {
            let content = try reader.content(archiveID: archiveID, invoiceID: invoiceID)
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            exportDirectory = directory
            let url = try await writer.write(content, to: .init(directory: directory))
            try Task.checkCancellation()
            guard generation == token else { throw CancellationError() }
            shareURL = url
        } catch {
            try? FileManager.default.removeItem(at: directory)
            if exportDirectory == directory { exportDirectory = nil }
            shareURL = nil
            if !(error is CancellationError) {
                alert = FeatureAlert(title: InvoiceHistoryCopy.exportFailureTitle, message: InvoiceHistoryCopy.exportFailure)
            }
        }
    }

    func sharingCompleted() {
        generation = UUID()
        shareURL = nil
        if let directory = exportDirectory { try? FileManager.default.removeItem(at: directory) }
        exportDirectory = nil
    }
}

enum InvoiceHistoryCopy {
    static let title = LocalizedStringResource("invoiceHistory.title", defaultValue: "Invoice History")
    static let localOnly = LocalizedStringResource("invoiceHistory.localOnly", defaultValue: "Local-only invoice history")
    static let notProtected = LocalizedStringResource("invoiceHistory.notProtected", defaultValue: "Not cloud-protected")
    static let explanation = LocalizedStringResource("invoiceHistory.explanation", defaultValue: "These original invoices are read-only and stay on this iPhone. They are not included in cloud backup. Export PDFs to keep a separate copy.")
    static let empty = LocalizedStringResource("invoiceHistory.empty", defaultValue: "No Local-only History")
    static let failure = LocalizedStringResource("invoiceHistory.failure", defaultValue: "Your saved history has not been changed. FarrierFlow couldn’t read it. Try again.")
    static let exportFailureTitle = LocalizedStringResource("invoiceHistory.exportFailure.title", defaultValue: "Couldn’t Create PDF")
    static let exportFailure = LocalizedStringResource("invoiceHistory.exportFailure.message", defaultValue: "The original invoice is unchanged. Try exporting again.")
}
