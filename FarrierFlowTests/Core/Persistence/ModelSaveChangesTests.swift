import Combine
import Foundation
import SwiftData
import Synchronization
import Testing
@testable import FarrierFlow

@Suite("Saved record invalidation")
@MainActor
struct ModelSaveChangesTests {
    @Test
    func adjacentBusinessSavesProduceOneRefresh() async throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "First")
        context.insert(client)
        try context.save()
        let count = Mutex(0)
        let (events, continuation) = AsyncStream<Void>.makeStream()
        let observer = ModelSaveChanges.publisher(in: container, entities: ["Client"]).sink {
            count.withLock { $0 += 1 }
            continuation.yield()
        }
        defer { observer.cancel(); continuation.finish() }
        client.name = "Second"
        try context.save()
        client.name = "Final"
        try context.save()
        var iterator = events.makeAsyncIterator()
        _ = await iterator.next()
        #expect(count.withLock { $0 } == 1)
        #expect(try ModelContext(container).fetch(FetchDescriptor<Client>()).first?.name == "Final")
    }

    @Test
    func checkpointAndUnrelatedEntitiesDoNotReloadBusinessProjections() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Client")
        let state = FarrierFlowSchemaV5.SyncState(deviceID: UUID())
        context.insert(client)
        context.insert(state)
        try context.save()
        func save(_ identifiers: [PersistentIdentifier]) -> Notification {
            Notification(name: ModelContext.didSave, object: context,
                userInfo: [ModelContext.NotificationKey.updatedIdentifiers.rawValue: identifiers])
        }
        #expect(!ModelSaveChanges.affects(save([state.persistentModelID]), container: container, entities: ["Client"]))
        #expect(!ModelSaveChanges.affects(save([client.persistentModelID]), container: container, entities: ["Invoice"]))
        #expect(ModelSaveChanges.affects(save([client.persistentModelID]), container: container, entities: ["Client"]))
        #expect(ModelSaveChanges.affects(save([]), container: container, entities: ["Client"]))
        let foreign = try ModelContainerFactory.inMemoryTest()
        #expect(!ModelSaveChanges.affects(save([]), container: foreign, entities: ["Client"]))
    }
}
