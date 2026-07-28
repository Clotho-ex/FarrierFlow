import Foundation
import Testing
@testable import FarrierFlow

@Suite("Photograph file store")
struct PhotographFileStoreTests {
    private let photoID = UUID(uuidString: "D4586522-AF85-4D45-826A-C4379B6DBD1E")!
    private let operationID = UUID(uuidString: "AB4DC20B-EA14-4D2A-8611-A0476AE6B4BD")!

    @Test
    func pathsUseOnlyApprovedDirectoryAndLowercaseUUIDConventions() throws {
        let applicationSupport = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Paths-"
        )
        let store = PhotographFileStore(applicationSupportURL: applicationSupport)

        #expect(store.rootURL.lastPathComponent == "HoofPhotographs")
        #expect(
            store.canonicalURL(for: photoID).lastPathComponent
                == "d4586522-af85-4d45-826a-c4379b6dbd1e.jpg"
        )
        #expect(
            store.temporaryURL(photoID: photoID, operationID: operationID).lastPathComponent
                == "d4586522-af85-4d45-826a-c4379b6dbd1e.ab4dc20b-ea14-4d2a-8611-a0476ae6b4bd.tmp"
        )
        #expect(
            store.quarantineURL(photoID: photoID, operationID: operationID).lastPathComponent
                == "d4586522-af85-4d45-826a-c4379b6dbd1e.ab4dc20b-ea14-4d2a-8611-a0476ae6b4bd.jpg"
        )
    }

    @Test
    func prepareCreatesProtectedDirectoriesWithoutBackupExclusion() throws {
        let applicationSupport = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Protection-"
        )
        let store = PhotographFileStore(applicationSupportURL: applicationSupport)

        try store.prepareDirectories()

        for directory in [store.rootURL, store.temporaryDirectoryURL, store.quarantineDirectoryURL] {
            let values = try directory.resourceValues(
                forKeys: [.isDirectoryKey, .fileProtectionKey, .isExcludedFromBackupKey]
            )
            #expect(values.isDirectory == true)
            #if targetEnvironment(simulator)
            #expect(values.fileProtection == nil || values.fileProtection == .complete)
            #else
            #expect(values.fileProtection == .complete)
            #endif
            #expect(values.isExcludedFromBackup != true)
        }
    }

    @Test
    func moveRefusesToOverwriteCanonicalCollision() throws {
        let applicationSupport = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Collision-"
        )
        let store = PhotographFileStore(applicationSupportURL: applicationSupport)
        try store.prepareDirectories()
        let source = store.temporaryURL(photoID: photoID, operationID: operationID)
        let destination = store.canonicalURL(for: photoID)
        try Data("new".utf8).write(to: source)
        try Data("existing".utf8).write(to: destination)

        #expect(throws: PhotographFileStoreError.destinationExists) {
            try store.moveWithoutOverwriting(from: source, to: destination)
        }
        #expect(try Data(contentsOf: destination) == Data("existing".utf8))
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test
    func inspectionRecognizesOnlyExactManagedRegularFiles() throws {
        let applicationSupport = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Inspection-"
        )
        let store = PhotographFileStore(applicationSupportURL: applicationSupport)
        try store.prepareDirectories()

        let canonical = store.canonicalURL(for: photoID)
        try Data("jpeg".utf8).write(to: canonical)
        let invalidUUID = store.rootURL.appending(
            path: "d4586522-af85-4d45-826a-c4379b6dbd1e-extra.jpg"
        )
        try Data("unknown".utf8).write(to: invalidUUID)
        let malformed = store.rootURL.appending(path: "notes.txt")
        try Data("unknown".utf8).write(to: malformed)
        let symlink = store.rootURL.appending(path: "d4586522-af85-4d45-826a-c4379b6dbd1f.jpg")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: canonical)

        let inspection = try store.inspectAllEntries()

        #expect(inspection.canonicalFiles == [photoID: canonical])
        #expect(Set(inspection.unknownEntries) == [invalidUUID, malformed, symlink])
    }

    @Test
    func prepareRejectsSymbolicLinkManagedDirectory() throws {
        let applicationSupport = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Photograph-Symlink-Root-\(UUID().uuidString)-"
        )
        let destination = applicationSupport.appending(
            path: "Outside",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )
        let root = applicationSupport.appending(
            path: PhotographConstants.rootDirectoryName,
            directoryHint: .isDirectory
        )
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: destination)

        #expect(throws: PhotographFileStoreError.directoryUnavailable) {
            try PhotographFileStore(rootURL: root).prepareDirectories()
        }
    }
}
