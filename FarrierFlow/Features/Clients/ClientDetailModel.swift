import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientDetailModel {
    private(set) var client: Client?
    private(set) var hasInvoiceableWork = false
    private(set) var invoices: [InvoiceSummary] = []
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        client = context.model(for: id) as? Client
        guard client != nil else {
            hasInvoiceableWork = false
            invoices = []
            return
        }
        do {
            hasInvoiceableWork = try InvoiceEligibilityRules.choices(
                for: id,
                in: context
            ).isEmpty == false
            invoices = try client?.invoices.map {
                try InvoiceProjection.summary(from: $0, locale: .current)
            }.sorted {
                if $0.invoiceDate != $1.invoiceDate {
                    return $0.invoiceDate > $1.invoiceDate
                }
                return $0.number.localizedStandardCompare($1.number) == .orderedDescending
            } ?? []
            alert = nil
        } catch {
            hasInvoiceableWork = false
            invoices = []
            alert = FeatureAlert(
                title: "Couldn’t Check Invoice Readiness",
                message: "The client is still available. Try loading their invoice work again."
            )
        }
    }

    func delete(in context: ModelContext) -> Bool {
        guard let client else { return false }
        self.client = nil
        do {
            try RecordDeletionRules.delete(client, in: context)
            return true
        } catch let block as RecordDeletionBlock {
            self.client = client
            alert = block.alert
            return false
        } catch {
            self.client = client
            alert = FeatureAlert(
                title: "Couldn’t Delete Client",
                message: "The client wasn’t deleted. Try again."
            )
            return false
        }
    }
}
