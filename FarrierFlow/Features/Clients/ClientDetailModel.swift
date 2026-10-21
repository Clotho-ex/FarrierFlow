import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientDetailModel {
    private(set) var client: ClientDetailSnapshot?
    private(set) var hasInvoiceableWork = false
    private(set) var invoices: [InvoiceSummary] = []
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        let record: Client
        do {
            guard let existing = try context.existingModel(Client.self, for: id) else {
                client = nil
                hasInvoiceableWork = false
                invoices = []
                return
            }
            record = existing
            client = ClientDetailSnapshot(client: record)
        } catch {
            client = nil
            hasInvoiceableWork = false
            invoices = []
            alert = FeatureAlert(
                title: "Client Unavailable",
                message: "The client couldn’t be loaded. Try again."
            )
            return
        }
        do {
            hasInvoiceableWork = try InvoiceEligibilityRules.choices(
                for: id,
                in: context
            ).isEmpty == false
            invoices = try record.invoices.map {
                try InvoiceProjection.summary(from: $0, locale: .current)
            }.sorted {
                if $0.invoiceDate != $1.invoiceDate {
                    return $0.invoiceDate > $1.invoiceDate
                }
                return $0.number.localizedStandardCompare($1.number) == .orderedDescending
            }
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

    func delete(
        in context: ModelContext,
        deleting: (Client, ModelContext) throws -> Void = { record, context in
            try RecordDeletionRules.delete(record, in: context)
        }
    ) -> Bool {
        guard let displayed = client else {
            alert = unavailableAlert
            return false
        }
        do {
            guard let record = try context.existingModel(Client.self, for: displayed.id) else {
                alert = unavailableAlert
                return false
            }
            try deleting(record, context)
            client = nil
            alert = nil
            return true
        } catch let block as RecordDeletionBlock {
            alert = block.alert
            return false
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Delete Client",
                message: "The client wasn’t deleted. Try again."
            )
            return false
        }
    }

    private var unavailableAlert: FeatureAlert {
        FeatureAlert(
            title: "Client Unavailable",
            message: "This client is no longer available."
        )
    }
}
