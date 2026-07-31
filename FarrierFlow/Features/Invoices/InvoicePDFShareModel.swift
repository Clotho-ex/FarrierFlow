import Foundation
import Observation
import SwiftData

@MainActor @Observable final class InvoicePDFShareModel {
    private let store: InvoicePDFTemporaryFileStore
    var shareURL: URL?
    private(set) var isPreparing = false
    var alert: FeatureAlert?
    init(store: InvoicePDFTemporaryFileStore = .init()) { self.store = store }
    func prepare(invoiceID: PersistentIdentifier, in context: ModelContext) {
        store.removeIfPresent(shareURL)
        shareURL = nil
        alert = nil
        isPreparing = true; defer { isPreparing = false }
        do { let content = try InvoicePDFContentBuilder.build(invoiceID: invoiceID, in: context); shareURL = try store.write(InvoicePDFRenderer().render(content), number: content.number); alert = nil }
        catch {
            shareURL = nil
            alert = FeatureAlert(
                title: "Couldn’t Create PDF",
                message: "The invoice is unchanged. Try again."
            )
        }
    }
    func retry(invoiceID: PersistentIdentifier, in context: ModelContext) { prepare(invoiceID: invoiceID, in: context) }
    func sharingCompleted() { store.removeIfPresent(shareURL); shareURL = nil }
}
