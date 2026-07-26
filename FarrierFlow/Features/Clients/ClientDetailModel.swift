import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientDetailModel {
    private(set) var client: Client?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        client = context.model(for: id) as? Client
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
