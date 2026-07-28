import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Photograph library")
@MainActor
struct PhotographLibraryTests {
    @Test
    func addPersistsOneOwnedRecordAndCanonicalFile() async throws {
        let fixture = try makeFixture()
        let id = UUID()
        let createdAt = Date(timeIntervalSinceReferenceDate: 1_234)

        let result = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(width: 800, height: 400),
            to: fixture.graph.visitHorseID,
            id: id,
            createdAt: createdAt
        )

        let context = ModelContext(fixture.graph.container)
        let photograph = try #require(
            context.fetch(FetchDescriptor<Photograph>()).first
        )
        #expect(result == id)
        #expect(photograph.id == id)
        #expect(photograph.createdAt == createdAt)
        #expect(photograph.pixelWidth == 800)
        #expect(photograph.pixelHeight == 400)
        #expect(photograph.byteCount > 0)
        #expect(photograph.visitHorse?.persistentModelID == fixture.graph.visitHorseID)
        let canonicalURL = fixture.store.canonicalURL(for: id)
        #expect(FileManager.default.fileExists(atPath: canonicalURL.path))
        let fileValues = try canonicalURL.resourceValues(
            forKeys: [.fileProtectionKey, .isExcludedFromBackupKey]
        )
        #if !targetEnvironment(simulator)
        #expect(fileValues.fileProtection == .complete)
        #endif
        #expect(fileValues.isExcludedFromBackup != true)
    }

    @Test
    func deleteRemovesMetadataOnlyAfterQuarantiningFile() async throws {
        let fixture = try makeFixture()
        let id = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: fixture.graph.visitHorseID
        )

        try await fixture.library.delete(id: id)

        let context = ModelContext(fixture.graph.container)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
        #expect(try fixture.store.inspectAllEntries().quarantineFiles.isEmpty)
    }

    @Test
    func failedAddSaveRollsBackMetadataAndCanonicalFile() async throws {
        let fixture = try makeFixture(saving: { _ in throw ForcedFailure.expected })
        let id = UUID()

        await #expect(throws: PhotographLibraryError.persistenceFailed) {
            try await fixture.library.add(
                sourceData: PhotographTestFixtures.jpeg(),
                to: fixture.graph.visitHorseID,
                id: id
            )
        }

        let context = ModelContext(fixture.graph.container)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
    }

    @Test
    func failedDeleteSaveRestoresCanonicalAndMetadata() async throws {
        let initial = try makeFixture()
        let id = try await initial.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: initial.graph.visitHorseID
        )
        let failingLibrary = PhotographTestFixtures.makeLibrary(
            graph: initial.graph,
            rootURL: initial.store.rootURL,
            saving: { _ in throw ForcedFailure.expected }
        )

        await #expect(throws: PhotographLibraryError.persistenceFailed) {
            try await failingLibrary.delete(id: id)
        }

        let context = ModelContext(initial.graph.container)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 1)
        #expect(FileManager.default.fileExists(atPath: initial.store.canonicalURL(for: id).path))
        #expect(try initial.store.inspectAllEntries().quarantineFiles.isEmpty)
    }

    @Test
    func unavailableRecordDoesNotConsumeSlotAndCanBeDeleted() async throws {
        let fixture = try makeFixture()
        let missingID = UUID()
        let context = ModelContext(fixture.graph.container)
        let visitHorse = try #require(
            context.model(for: fixture.graph.visitHorseID) as? VisitHorse
        )
        let photograph = Photograph(
            id: missingID,
            createdAt: .now,
            pixelWidth: 100,
            pixelHeight: 100,
            byteCount: 1,
            visitHorse: visitHorse
        )
        context.insert(photograph)
        visitHorse.photographs.append(photograph)
        try DomainGraphValidator.save(context)

        #expect(try fixture.library.items(for: fixture.graph.visitHorseID).first?.availability == .unavailable)
        _ = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: fixture.graph.visitHorseID
        )
        try await fixture.library.delete(id: missingID)

        let verification = ModelContext(fixture.graph.container)
        #expect(try verification.fetchCount(FetchDescriptor<Photograph>()) == 1)
    }

    @Test
    func collisionRefusesOverwriteAndCreatesNoMetadata() async throws {
        let fixture = try makeFixture()
        try fixture.store.prepareDirectories()
        let id = UUID()
        let original = Data("existing".utf8)
        try original.write(to: fixture.store.canonicalURL(for: id))

        await #expect(throws: PhotographFileStoreError.destinationExists) {
            try await fixture.library.add(
                sourceData: PhotographTestFixtures.jpeg(),
                to: fixture.graph.visitHorseID,
                id: id
            )
        }

        #expect(try Data(contentsOf: fixture.store.canonicalURL(for: id)) == original)
        let context = ModelContext(fixture.graph.container)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 0)
    }

    @Test
    func metadataUUIDCollisionFailsWithoutCreatingAFile() async throws {
        let fixture = try makeFixture()
        let id = UUID()
        let context = ModelContext(fixture.graph.container)
        let visitHorse = try #require(
            context.model(for: fixture.graph.visitHorseID) as? VisitHorse
        )
        let existing = Photograph(
            id: id,
            createdAt: .now,
            pixelWidth: 100,
            pixelHeight: 100,
            byteCount: 1,
            visitHorse: visitHorse
        )
        context.insert(existing)
        visitHorse.photographs.append(existing)
        try DomainGraphValidator.save(context)

        await #expect(throws: PhotographFileStoreError.destinationExists) {
            try await fixture.library.add(
                sourceData: PhotographTestFixtures.jpeg(),
                to: fixture.graph.visitHorseID,
                id: id
            )
        }

        #expect(!FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
        let verification = ModelContext(fixture.graph.container)
        #expect(try verification.fetchCount(FetchDescriptor<Photograph>()) == 1)
    }

    @Test
    func photoAwareDiscardRemovesVisitMetadataAndFiles() async throws {
        let fixture = try makeFixture()
        let id = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: fixture.graph.visitHorseID
        )

        try await fixture.library.discardInProgressVisit(id: fixture.graph.visitID)

        let context = ModelContext(fixture.graph.container)
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
    }

    @Test
    func failedPhotoAwareDiscardRestoresEveryCanonicalAndKeepsVisit() async throws {
        let fixture = try makeFixture()
        let id = try await fixture.library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: fixture.graph.visitHorseID
        )
        let failingLibrary = PhotographTestFixtures.makeLibrary(
            graph: fixture.graph,
            rootURL: fixture.store.rootURL,
            discarding: { _, _ in throw ForcedFailure.expected }
        )

        await #expect(throws: ForcedFailure.expected) {
            try await failingLibrary.discardInProgressVisit(id: fixture.graph.visitID)
        }

        let context = ModelContext(fixture.graph.container)
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 1)
        #expect(FileManager.default.fileExists(atPath: fixture.store.canonicalURL(for: id).path))
        #expect(try fixture.store.inspectAllEntries().quarantineFiles.isEmpty)
    }

    @Test
    func completedOutcomeCorrectionDoesNotChangePhotographOwnershipOrFile() async throws {
        let graph = try PhotographTestFixtures.makeVisitGraph(
            completedAt: .now.addingTimeInterval(60),
            horseCount: 2
        )
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Correction-\(UUID().uuidString)-"
        )
        let store = PhotographFileStore(
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        let library = PhotographTestFixtures.makeLibrary(
            graph: graph,
            rootURL: store.rootURL
        )
        let ownerID = graph.visitHorseIDs[1]
        let photographID = try await library.add(
            sourceData: PhotographTestFixtures.jpeg(),
            to: ownerID
        )
        let correctionContext = ModelContext(graph.container)
        var draft = try VisitSaveUseCase.loadDraft(
            visitID: graph.visitID,
            in: correctionContext
        )
        let index = try #require(draft.horses.firstIndex { $0.id == ownerID })
        draft.horses[index].outcome = .serviced
        draft.horses[index].workNotes = "Completed work"

        _ = try VisitSaveUseCase.saveCorrection(
            draft: draft,
            in: correctionContext
        )

        let verification = ModelContext(graph.container)
        let photograph = try #require(
            verification.fetch(FetchDescriptor<Photograph>()).first
        )
        #expect(photograph.id == photographID)
        #expect(photograph.visitHorse?.persistentModelID == ownerID)
        #expect(FileManager.default.fileExists(atPath: store.canonicalURL(for: photographID).path))
    }

    private func makeFixture(
        saving: @escaping @MainActor (ModelContext) throws -> Void = {
            try DomainGraphValidator.save($0)
        }
    ) throws -> LibraryFixture {
        let graph = try PhotographTestFixtures.makeVisitGraph()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Library-\(UUID().uuidString)-"
        )
        let store = PhotographFileStore(
            rootURL: directory.appending(path: "HoofPhotographs", directoryHint: .isDirectory)
        )
        return LibraryFixture(
            graph: graph,
            store: store,
            library: PhotographTestFixtures.makeLibrary(
                graph: graph,
                rootURL: store.rootURL,
                saving: saving
            )
        )
    }
}

private struct LibraryFixture {
    let graph: PhotographTestFixtures.VisitGraph
    let store: PhotographFileStore
    let library: PhotographLibrary
}

private enum ForcedFailure: Error {
    case expected
}
