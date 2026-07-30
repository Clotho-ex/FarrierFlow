import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Horse default Service detail")
@MainActor
struct HorseDetailModelTests {
    @Test
    func projectsSelectedDefaultWithLocalizedUSDPrice() throws {
        let graph = try makeHorseGraph()
        let service = ModelFixtures.makeService(name: "Trim", defaultAmountMinorUnits: 7_500, in: graph.context)
        graph.horse.defaultService = service
        try DomainGraphValidator.save(graph.context)

        let model = HorseDetailModel()
        model.load(
            id: graph.horse.persistentModelID,
            in: graph.context,
            locale: Locale(identifier: "en_US")
        )

        #expect(model.defaultService?.name == "Trim")
        #expect(model.defaultService?.formattedAmount == "$75.00")
    }

    @Test
    func missingDefaultProjectsAsNotSet() throws {
        let graph = try makeHorseGraph()
        let model = HorseDetailModel()
        model.load(id: graph.horse.persistentModelID, in: graph.context)

        #expect(model.defaultService == nil)
    }

    private func makeHorseGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        horse: Horse
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        return (container, context, horse)
    }
}
