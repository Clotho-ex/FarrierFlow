import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Photograph collection load states")
@MainActor
struct PhotographCollectionLoadStateTests {
    @Test
    func successfulEmptyFetchIsLoadedNotFailed() throws {
        let fixture = try makeFixture()
        let model = PhotographCollectionModel(
            visitHorseID: fixture.graph.visitHorseID,
            horseName: "Milo",
            library: fixture.library,
            itemsLoader: { _ in [] }
        )

        model.load()

        #expect(model.loadState == .loaded)
        #expect(model.items.isEmpty)
        #expect(model.loadFailure == nil)
    }

    @Test
    func initialFetchFailureIsFailedNotEmptyCollection() throws {
        let fixture = try makeFixture()
        let model = PhotographCollectionModel(
            visitHorseID: fixture.graph.visitHorseID,
            horseName: "Milo",
            library: fixture.library,
            itemsLoader: { _ in throw LoadFailure.expected }
        )

        model.load()

        #expect(model.loadState == .failed)
        #expect(model.items.isEmpty)
        #expect(model.hasInitialLoadFailure)
        #expect(model.loadFailure?.title == "Photographs Unavailable")
    }

    @Test
    func retrySuccessReplacesFailureState() throws {
        let fixture = try makeFixture()
        var shouldFail = true
        let item = makeItem()
        let model = PhotographCollectionModel(
            visitHorseID: fixture.graph.visitHorseID,
            horseName: "Milo",
            library: fixture.library,
            itemsLoader: { _ in
                defer { shouldFail = false }
                if shouldFail { throw LoadFailure.expected }
                return [item]
            }
        )

        model.load()
        model.load()

        #expect(model.loadState == .loaded)
        #expect(model.items == [item])
        #expect(model.loadFailure == nil)
    }

    @Test
    func refreshFailureRetainsLoadedItemsAndExposesFailure() throws {
        let fixture = try makeFixture()
        var shouldFail = false
        let item = makeItem()
        let model = PhotographCollectionModel(
            visitHorseID: fixture.graph.visitHorseID,
            horseName: "Milo",
            library: fixture.library,
            itemsLoader: { _ in
                if shouldFail { throw LoadFailure.expected }
                return [item]
            }
        )

        model.load()
        shouldFail = true
        model.load()

        #expect(model.loadState == .failed)
        #expect(model.items == [item])
        #expect(!model.hasInitialLoadFailure)
        #expect(model.loadFailure != nil)
    }

    @Test
    func protectedDataFailureDoesNotBecomeLoadedEmptyState() throws {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Protected-"
        )
        let library = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory),
            protectedDataAvailable: { false }
        )
        let model = PhotographCollectionModel(
            visitHorseID: graph.visitHorseID,
            horseName: "Milo",
            library: library
        )

        model.load()

        #expect(model.loadState == .failed)
        #expect(model.hasInitialLoadFailure)
        #expect(model.items.isEmpty)
    }

    @Test
    func countStateDistinguishesLoadingLoadedAndUnavailable() throws {
        let fixture = try makeFixture()
        let item = makeItem()
        let loaded = PhotographCountModel(
            visitHorseID: fixture.graph.visitHorseID,
            library: fixture.library,
            loader: { _ in [item] }
        )
        let unavailable = PhotographCountModel(
            visitHorseID: fixture.graph.visitHorseID,
            library: fixture.library,
            loader: { _ in throw LoadFailure.expected }
        )

        #expect(loaded.state == .loading)
        loaded.load()
        unavailable.load()

        #expect(loaded.state == .loaded(1))
        #expect(unavailable.state == .unavailable)
    }

    private func makeFixture() throws -> CollectionFixture {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Collection-"
        )
        let library = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        return CollectionFixture(graph: graph, library: library)
    }

    private func makeItem() -> PhotographItem {
        PhotographItem(
            id: UUID(),
            createdAt: .now,
            pixelWidth: 80,
            pixelHeight: 60,
            byteCount: 1,
            availability: .available
        )
    }
}

private struct CollectionFixture {
    let graph: PhotographTestFixtures.VisitGraph
    let library: PhotographLibrary
}

private enum LoadFailure: Error {
    case expected
}
