import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Photograph reconciliation")
@MainActor
struct PhotographReconcilerTests {
    @Test
    func restoresSingleQuarantineForExistingMetadata() async throws {
        let fixture = try makeFixture()
        let id = try insertPhotographMetadata(in: fixture.graph)
        try fixture.store.prepareDirectories()
        let quarantine = fixture.store.quarantineURL(photoID: id, operationID: UUID())
        try Data("jpeg".utf8).write(to: quarantine)

        try await fixture.library.prepareAndReconcile()

        #expect(FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
        #expect(!FileManager.default.fileExists(atPath: quarantine.path))
    }

    @Test
    func purgesManagedCanonicalQuarantineAndTemporaryOrphans() async throws {
        let fixture = try makeFixture()
        try fixture.store.prepareDirectories()
        let canonical = fixture.store.canonicalURL(for: UUID())
        let quarantine = fixture.store.quarantineURL(photoID: UUID(), operationID: UUID())
        let temporary = fixture.store.temporaryURL(photoID: UUID(), operationID: UUID())
        for url in [canonical, quarantine, temporary] {
            try Data("orphan".utf8).write(to: url)
        }

        try await fixture.library.prepareAndReconcile()

        for url in [canonical, quarantine, temporary] {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test
    func ambiguousQuarantinesCauseNoMutation() async throws {
        let fixture = try makeFixture()
        let id = try insertPhotographMetadata(in: fixture.graph)
        try fixture.store.prepareDirectories()
        let first = fixture.store.quarantineURL(photoID: id, operationID: UUID())
        let second = fixture.store.quarantineURL(photoID: id, operationID: UUID())
        let orphan = fixture.store.canonicalURL(for: UUID())
        for url in [first, second, orphan] {
            try Data("preserve".utf8).write(to: url)
        }

        await #expect(throws: PhotographLibraryError.ambiguousQuarantine) {
            try await fixture.library.prepareAndReconcile()
        }

        for url in [first, second, orphan] {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test
    func protectedDataFailureMutatesNothing() async throws {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Reconcile-Protected-\(UUID().uuidString)-"
        )
        let store = PhotographFileStore(
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        try store.prepareDirectories()
        let orphan = store.canonicalURL(for: UUID())
        try Data("preserve".utf8).write(to: orphan)
        let library = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: store.rootURL,
            protectedDataAvailable: { false }
        )

        await #expect(throws: PhotographLibraryError.protectedDataUnavailable) {
            try await library.prepareAndReconcile()
        }
        #expect(FileManager.default.fileExists(atPath: orphan.path))
    }

    @Test
    func reconciliationIsIdempotent() async throws {
        let fixture = try makeFixture()
        try fixture.store.prepareDirectories()
        let orphan = fixture.store.canonicalURL(for: UUID())
        try Data("orphan".utf8).write(to: orphan)

        try await fixture.library.prepareAndReconcile()
        let firstInspection = try fixture.store.inspectAllEntries()
        try await fixture.library.prepareAndReconcile()
        let secondInspection = try fixture.store.inspectAllEntries()

        #expect(firstInspection == secondInspection)
        #expect(firstInspection.canonicalFiles.isEmpty)
    }

    private func insertPhotographMetadata(
        in graph: PhotographTestFixtures.VisitGraph
    ) throws -> UUID {
        let context = ModelContext(graph.container)
        let visitHorse = try #require(
            context.model(for: graph.visitHorseID) as? VisitHorse
        )
        let id = UUID()
        let photograph = Photograph(
            id: id,
            createdAt: .now,
            pixelWidth: 100,
            pixelHeight: 100,
            byteCount: 4,
            visitHorse: visitHorse
        )
        context.insert(photograph)
        visitHorse.photographs.append(photograph)
        try DomainGraphValidator.save(context)
        return id
    }

    private func makeFixture() throws -> ReconciliationFixture {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Reconcile-\(UUID().uuidString)-"
        )
        let store = PhotographFileStore(
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        return ReconciliationFixture(
            graph: graph,
            store: store,
            library: PhotographTestFixtures.makeLibrary(
                graph: graph,
                rootURL: store.rootURL
            )
        )
    }
}

private struct ReconciliationFixture {
    let graph: PhotographTestFixtures.VisitGraph
    let store: PhotographFileStore
    let library: PhotographLibrary
}
