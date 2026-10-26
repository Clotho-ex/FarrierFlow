import Foundation
import Observation
import SwiftData

nonisolated enum ClientListLoadState: Equatable { case loading, loaded, failed }

struct ClientListSnapshot: Equatable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let phone: String?
    let email: String?
    let horseNames: [String]
    let horseCount: Int

    init(client: Client) {
        id = client.persistentModelID
        name = client.name
        phone = client.phone
        email = client.email
        horseNames = client.horses.map(\.name).sorted()
        horseCount = client.horses.count
    }

    func matchesSearch(_ query: String) -> Bool {
        if RecordSearch.matches(query, fields: [name, phone ?? "", email ?? ""] + horseNames) { return true }
        let digits = query.filter(\.isNumber)
        guard !digits.isEmpty, query.allSatisfy({ $0.isNumber || $0.isWhitespace || "+()- .".contains($0) }) else { return false }
        return phone?.filter(\.isNumber).contains(digits) == true
    }
}

@MainActor
@Observable
final class ClientListModel {
    @ObservationIgnored private let fetching: (FetchDescriptor<Client>, ModelContext) throws -> [Client]
    private(set) var clients: [ClientListSnapshot] = []
    private(set) var loadState = ClientListLoadState.loading
    var alert: FeatureAlert?

    init(fetching: @escaping (FetchDescriptor<Client>, ModelContext) throws -> [Client] = { try $1.fetch($0) }) {
        self.fetching = fetching
    }

    func load(in context: ModelContext) {
        if clients.isEmpty, loadState != .loaded { loadState = .loading }
        do {
            var descriptor = FetchDescriptor<Client>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
            descriptor.relationshipKeyPathsForPrefetching = [\.horses]
            let loaded = try fetching(descriptor, context).map(ClientListSnapshot.init)
            if loaded != clients {
                clients = loaded
            }
            if loadState != .loaded { loadState = .loaded }
            if alert != nil { alert = nil }
        } catch {
            loadState = .failed
            alert = FeatureAlert(
                title: "Couldn’t Load Clients",
                message: "FarrierFlow couldn’t load your clients."
            )
        }
    }
}
