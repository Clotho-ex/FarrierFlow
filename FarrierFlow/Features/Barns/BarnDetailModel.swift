import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BarnDetailModel {
    private(set) var barn: Barn?
    private(set) var eligibleHorses: [Horse] = []
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        barn = context.model(for: id) as? Barn
        reloadEligibleHorses(in: context)
    }

    func reloadEligibleHorses(in context: ModelContext) {
        guard let barn else {
            eligibleHorses = []
            return
        }
        let destinationID = barn.persistentModelID
        let descriptor = FetchDescriptor<Horse>(
            sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
        )
        eligibleHorses = (try? context.fetch(descriptor))?.filter {
            $0.appointmentHorses.isEmpty
                && $0.currentBarn?.persistentModelID != destinationID
                && $0.client != nil
                && $0.currentBarn != nil
        } ?? []
    }

    func delete(in context: ModelContext) -> Bool {
        guard let barn else { return false }
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
