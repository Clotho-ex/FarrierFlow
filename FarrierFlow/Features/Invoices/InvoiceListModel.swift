import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum InvoiceListLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class InvoiceListModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "InvoiceList"
    )

    private(set) var summaries: [InvoiceSummary] = []
    private(set) var loadState: InvoiceListLoadState = .loading
    var alert: FeatureAlert?

    func load(in context: ModelContext, locale: Locale = .current) {
        loadState = .loading
        do {
            let invoices = try context.fetch(FetchDescriptor<Invoice>())
            summaries = try invoices.sorted { $0.number > $1.number }.map { invoice in
                try InvoiceProjection.summary(from: invoice, locale: locale)
            }
            alert = nil
            loadState = .loaded
        } catch {
            Self.logger.error("Failed to load invoices: \(error, privacy: .public)")
            summaries = []
            loadState = .failed
            alert = FeatureAlert(
                title: "Invoices Unavailable",
                message: "FarrierFlow couldn’t load your invoices. Try again."
            )
        }
    }
}
