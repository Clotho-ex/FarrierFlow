import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BarnDetailModel {
    private(set) var barn: Barn?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        barn = context.model(for: id) as? Barn
    }

    func delete(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) -> Bool {
        guard let barn else { return false }
        return coordinator.withMutation {
            self.barn = nil
            do {
                try RecordDeletionRules.delete(barn, in: context)
                return true
            } catch let block as RecordDeletionBlock {
                self.barn = barn
                alert = block.alert
                return false
            } catch {
                self.barn = barn
                alert = FeatureAlert(
                    title: "Couldn’t Delete Service Location",
                    message: "The service location wasn’t deleted. Try again."
                )
                return false
            }
        }
    }
}
