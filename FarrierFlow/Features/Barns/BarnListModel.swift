import Foundation
import Observation
import SwiftData

nonisolated enum BarnListLoadState: Equatable { case loading, loaded, failed }

@MainActor
@Observable
final class BarnListModel {
    @ObservationIgnored private let fetching: (FetchDescriptor<Barn>, ModelContext) throws -> [Barn]
    private(set) var barns: [BarnDetailSnapshot] = []
    private(set) var loadState = BarnListLoadState.loading
    var alert: FeatureAlert?

    init(fetching: @escaping (FetchDescriptor<Barn>, ModelContext) throws -> [Barn] = { try $1.fetch($0) }) {
        self.fetching = fetching
    }

    func load(in context: ModelContext) {
        if barns.isEmpty, loadState != .loaded { loadState = .loading }
        do {
            barns = try fetching(
                FetchDescriptor<Barn>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                ), context
            ).map(BarnDetailSnapshot.init)
            if loadState != .loaded { loadState = .loaded }
            if alert != nil { alert = nil }
        } catch {
            loadState = .failed
            alert = FeatureAlert(
                title: "Couldn’t Load Service Locations",
                message: "FarrierFlow couldn’t load your service locations."
            )
        }
    }
}
