import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Model container configurations")
@MainActor
struct ModelContainerFactoryTests {
    @Test
    func inMemoryTestIsCleanWritableAndRegistersCurrentV3() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let configuration = try #require(container.configurations.first)

        #expect(configuration.isStoredInMemoryOnly)
        #expect(Set(container.schema.entities.map(\.name)) == [
            "Client",
            "Barn",
            "Horse",
            "Appointment",
            "AppointmentHorse",
            "Visit",
            "VisitHorse",
            "Photograph",
        ])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Client>()) == 0)

        try insertCompleteGraph(in: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<AppointmentHorse>()) == 1)
    }

    @Test
    func previewIsInMemoryAndClearlySynthetic() throws {
        let container = try ModelContainerFactory.preview()
        let configuration = try #require(container.configurations.first)
        let clients = try container.mainContext.fetch(FetchDescriptor<Client>())
        let barns = try container.mainContext.fetch(FetchDescriptor<Barn>())

        #expect(configuration.isStoredInMemoryOnly)
        #expect(clients.count == 1)
        #expect(barns.count == 1)
        #expect(clients.first?.name == "Preview Client")
        #expect(barns.first?.name == "Preview Service Location")
    }

    @Test
    func persistentStoreUsesExactURLAndIsDurable() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Container-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let configuration = try #require(container.configurations.first)

            #expect(configuration.url == storeURL)
            #expect(!configuration.isStoredInMemoryOnly)
            try insertCompleteGraph(in: container.mainContext)
        }
    }

    @Test
    func testContainersDoNotUseTheProductionStoreURL() throws {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV1.self)
        let productionConfiguration = ModelConfiguration(
            "FarrierFlowV1",
            schema: schema,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let first = try ModelContainerFactory.inMemoryTest()
        let second = try ModelContainerFactory.inMemoryTest()

        #expect(first.configurations.first?.url != productionConfiguration.url)
        #expect(second.configurations.first?.url != productionConfiguration.url)
    }

    private func insertCompleteGraph(in context: ModelContext) throws {
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        context.insert(client)
        context.insert(barn)

        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        _ = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        try context.save()
    }

}
