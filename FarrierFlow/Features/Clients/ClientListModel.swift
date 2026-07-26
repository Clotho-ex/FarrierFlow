import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientListModel {
    private(set) var clients: [Client] = []
    var alert: FeatureAlert?

    func load(in context: ModelContext) {
        do {
            clients = try context.fetch(
                FetchDescriptor<Client>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Load Clients",
                message: "FarrierFlow couldn’t load your clients."
            )
        }
    }
}
