import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BarnListModel {
    private(set) var barns: [Barn] = []
    var alert: FeatureAlert?

    func load(in context: ModelContext) {
        do {
            barns = try context.fetch(
                FetchDescriptor<Barn>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Load Service Locations",
                message: "FarrierFlow couldn’t load your service locations."
            )
        }
    }
}
