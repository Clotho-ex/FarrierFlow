import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum InvoiceDetailLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class InvoiceDetailModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "InvoiceDetail"
    )

    let invoiceID: PersistentIdentifier
    private(set) var detail: InvoiceDetail?
    private(set) var loadState: InvoiceDetailLoadState = .loading
    private(set) var didDelete = false
    var alert: FeatureAlert?

    var canMarkPaid: Bool {
        detail?.status == .unpaid && detail?.total != .unavailable
    }

    var canDelete: Bool {
        detail?.status == .unpaid
    }

    init(invoiceID: PersistentIdentifier) {
        self.invoiceID = invoiceID
    }

    func load(in context: ModelContext, locale: Locale = .current) {
        loadState = .loading
        didDelete = false
        do {
            guard let invoice = try context.existingModel(Invoice.self, for: invoiceID) else {
                throw InvoiceDetailError.invoiceUnavailable
            }
            detail = try InvoiceProjection.detail(from: invoice, locale: locale)
            alert = nil
            loadState = .loaded
        } catch {
            Self.logger.error("Failed to load invoice detail: \(error, privacy: .public)")
            detail = nil
            loadState = .failed
            alert = FeatureAlert(
                title: "Invoice Unavailable",
                message: "FarrierFlow couldn’t load this invoice. Try again."
            )
        }
    }

    func markPaid(now: Date = .now, in context: ModelContext) {
        do {
            try InvoiceStatusUseCase.markPaid(
                invoiceID: invoiceID,
                paidAt: now,
                in: context
            )
            load(in: context)
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Mark Invoice Paid",
                message: "The invoice remains unchanged. Try again."
            )
        }
    }

    func delete(in context: ModelContext) {
        do {
            try InvoiceDeletionUseCase.deleteUnpaid(invoiceID: invoiceID, in: context)
            didDelete = true
            detail = nil
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Delete Invoice",
                message: "The invoice wasn’t deleted. Try again."
            )
        }
    }
}

nonisolated enum InvoiceDetailError: Error, Equatable {
    case invoiceUnavailable
}
