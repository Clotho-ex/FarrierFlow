import Foundation
import Observation
import SwiftData

struct ClientListSnapshot: Equatable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let phone: String?
    let horseCount: Int

    init(client: Client) {
        id = client.persistentModelID
        name = client.name
        phone = client.phone
        horseCount = client.horses.count
    }
}

@MainActor
@Observable
final class ClientListModel {
    private(set) var clients: [ClientListSnapshot] = []
    var alert: FeatureAlert?

    func load(in context: ModelContext) {
        do {
            let loaded = try context.fetch(
                FetchDescriptor<Client>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            ).map(ClientListSnapshot.init)
            if loaded != clients {
                clients = loaded
            }
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Load Clients",
                message: "FarrierFlow couldn’t load your clients."
            )
        }
    }
}
