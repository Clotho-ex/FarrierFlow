import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Field record search")
@MainActor
struct RecordSearchTests {
    @Test
    func searchIgnoresCaseDiacriticsAndExtraWhitespaceAcrossRecordFields() {
        #expect(RecordSearch.matches("  JOSE atlas  ", fields: ["José Álvarez", "Atlas"]))
        #expect(RecordSearch.matches("", fields: []))
        #expect(!RecordSearch.matches("Jose missing", fields: ["José Álvarez", "Atlas"]))
        #expect(RecordSearch.matches("0148", fields: ["Jordan Ellis", "0148"]))
    }

    @Test
    func customerSearchUsesSavedHorseAndContactRelationshipsWithoutChangingRecords() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "José Álvarez", phone: "+1 555 0148", email: "jose@example.com")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Atlas", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        let model = ClientListModel()
        model.load(in: ModelContext(container))
        let snapshot = try #require(model.clients.first)
        for query in ["jose", "ATLAS", "0148", "+1(555)0148", "jose@example.com", "jose atlas"] {
            #expect(snapshot.matchesSearch(query))
        }
        #expect(!snapshot.matchesSearch("Peanut"))
        #expect(snapshot.horseCount == 1)
        #expect(!context.hasChanges)
    }

    @Test
    func directionsKeepUntrustedAddressAsOneDestination() throws {
        let address = "240 Oak & Pine Lane?daddr=elsewhere#gate, İzmir"
        let url = try #require(ServiceLocationDirections.url(for: address))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "https")
        #expect(components.host == "maps.apple.com")
        #expect(components.queryItems == [URLQueryItem(name: "daddr", value: address)])
        #expect(components.fragment == nil)
        #expect(ServiceLocationDirections.url(for: " \n") == nil)
    }
}
