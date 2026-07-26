import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HorseDetailModel {
    private(set) var horse: Horse?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        horse = context.model(for: id) as? Horse
    }

    func delete(in context: ModelContext) -> Bool {
        guard let horse else { return false }
        self.horse = nil
        do {
            try RecordDeletionRules.delete(horse, in: context)
            return true
        } catch let block as RecordDeletionBlock {
            self.horse = horse
            alert = block.alert
            return false
        } catch {
            self.horse = horse
            alert = FeatureAlert(
                title: "Couldn’t Delete Horse",
                message: "The horse wasn’t deleted. Try again."
            )
            return false
        }
    }
}
