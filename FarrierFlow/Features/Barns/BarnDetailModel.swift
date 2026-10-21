import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BarnDetailModel {
    private(set) var barn: BarnDetailSnapshot?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        do {
            barn = try context.existingModel(Barn.self, for: id).map(BarnDetailSnapshot.init)
        } catch {
            barn = nil
            alert = FeatureAlert(
                title: "Service Location Unavailable",
                message: "The service location couldn’t be loaded. Try again."
            )
        }
    }

    func delete(
        in context: ModelContext,
        deleting: (Barn, ModelContext) throws -> Void = { record, context in
            try RecordDeletionRules.delete(record, in: context)
        }
    ) -> Bool {
        guard let displayed = barn else {
            alert = unavailableAlert
            return false
        }
        do {
            guard let record = try context.existingModel(Barn.self, for: displayed.id) else {
                alert = unavailableAlert
                return false
            }
            try deleting(record, context)
            barn = nil
            alert = nil
            return true
        } catch let block as RecordDeletionBlock {
            alert = block.alert
            return false
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Delete Service Location",
                message: "The service location wasn’t deleted. Try again."
            )
            return false
        }
    }

    private var unavailableAlert: FeatureAlert {
        FeatureAlert(
            title: "Service Location Unavailable",
            message: "This service location is no longer available."
        )
    }
}
