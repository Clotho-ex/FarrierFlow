import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientDetailModel {
    private(set) var client: Client?
    private(set) var hasInvoiceableWork = false
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        client = context.model(for: id) as? Client
        guard client != nil else {
            hasInvoiceableWork = false
            return
        }
        do {
            hasInvoiceableWork = try InvoiceEligibilityRules.choices(
                for: id,
                in: context
            ).isEmpty == false
            alert = nil
        } catch {
            hasInvoiceableWork = false
            alert = FeatureAlert(
                title: "Couldn’t Check Invoice Readiness",
                message: "The client is still available. Try loading their invoice work again."
            )
        }
    }

    func delete(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) -> Bool {
        guard let client else { return false }
        return coordinator.withMutation {
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
}
