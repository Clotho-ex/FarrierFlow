import Foundation
import Observation
import SwiftData

nonisolated struct InvoicePDFDocumentWriter: Sendable {
    typealias Render = @Sendable (InvoicePDFContent) throws -> Data

    private let render: Render

    init(
        render: @escaping Render = { content in
            try InvoicePDFRenderer().render(content)
        }
    ) {
        self.render = render
    }

    func write(
        _ content: InvoicePDFContent,
        to store: InvoicePDFTemporaryFileStore
    ) async throws -> URL {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let data = try render(content)
            try Task.checkCancellation()
            let url = try store.write(data, number: content.number)
            do {
                try Task.checkCancellation()
                return url
            } catch {
                store.removeIfPresent(url)
                throw error
            }
        }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

@MainActor @Observable final class InvoicePDFShareModel {
    private let store: InvoicePDFTemporaryFileStore
    private let writer: InvoicePDFDocumentWriter
    var shareURL: URL?
    private(set) var isPreparing = false
    var alert: FeatureAlert?

    init(
        store: InvoicePDFTemporaryFileStore = .init(),
        writer: InvoicePDFDocumentWriter = .init()
    ) {
        self.store = store
        self.writer = writer
    }

    func prepare(
        invoiceID: PersistentIdentifier,
        in context: ModelContext
    ) async {
        guard !isPreparing else { return }
        store.removeIfPresent(shareURL)
        shareURL = nil
        alert = nil
        isPreparing = true
        defer { isPreparing = false }

        do {
            let content = try InvoicePDFContentBuilder.build(
                invoiceID: invoiceID,
                in: context
            )
            try Task.checkCancellation()
            let preparedURL = try await writer.write(content, to: store)
            do {
                try Task.checkCancellation()
                shareURL = preparedURL
            } catch {
                store.removeIfPresent(preparedURL)
                throw error
            }
            alert = nil
        } catch is CancellationError {
            shareURL = nil
            alert = nil
        } catch {
            shareURL = nil
            alert = FeatureAlert(
                title: "Couldn’t Create PDF",
                message: "The invoice is unchanged. Try again."
            )
        }
    }

    func retry(
        invoiceID: PersistentIdentifier,
        in context: ModelContext
    ) async {
        await prepare(invoiceID: invoiceID, in: context)
    }

    func sharingCompleted() {
        store.removeIfPresent(shareURL)
        shareURL = nil
    }
}
