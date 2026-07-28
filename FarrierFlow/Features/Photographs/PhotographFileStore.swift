import Foundation

nonisolated struct ManagedOperationFile: Equatable, Sendable {
    let photoID: UUID
    let operationID: UUID
    let url: URL
}

nonisolated struct PhotographFileInspection: Equatable, Sendable {
    var canonicalFiles: [UUID: URL] = [:]
    var temporaryFiles: [ManagedOperationFile] = []
    var quarantineFiles: [UUID: [ManagedOperationFile]] = [:]
    var unknownEntries: [URL] = []
}

nonisolated struct PhotographFileStore: Sendable {
    let rootURL: URL

    var temporaryDirectoryURL: URL {
        rootURL.appending(path: PhotographConstants.temporaryDirectoryName, directoryHint: .isDirectory)
    }

    var quarantineDirectoryURL: URL {
        rootURL.appending(path: PhotographConstants.quarantineDirectoryName, directoryHint: .isDirectory)
    }

    init(applicationSupportURL: URL) {
        rootURL = applicationSupportURL.appending(
            path: PhotographConstants.rootDirectoryName,
            directoryHint: .isDirectory
        )
    }

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func canonicalURL(for id: UUID) -> URL {
        rootURL.appending(path: PhotographConstants.filename(for: id))
    }

    func temporaryURL(photoID: UUID, operationID: UUID) -> URL {
        temporaryDirectoryURL.appending(
            path: PhotographConstants.operationFilename(
                photoID: photoID,
                operationID: operationID,
                extension: PhotographConstants.temporaryExtension
            )
        )
    }

    func quarantineURL(photoID: UUID, operationID: UUID) -> URL {
        quarantineDirectoryURL.appending(
            path: PhotographConstants.operationFilename(
                photoID: photoID,
                operationID: operationID,
                extension: PhotographConstants.jpegExtension
            )
        )
    }

    func prepareDirectories() throws {
        for directory in [rootURL, temporaryDirectoryURL, quarantineDirectoryURL] {
            if FileManager.default.fileExists(atPath: directory.path) {
                let existingValues = try directory.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                )
                guard existingValues.isDirectory == true,
                      existingValues.isSymbolicLink != true else {
                    throw PhotographFileStoreError.directoryUnavailable
                }
            }
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let createdValues = try directory.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard createdValues.isDirectory == true,
                  createdValues.isSymbolicLink != true else {
                throw PhotographFileStoreError.directoryUnavailable
            }
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: directory.path
            )
        }
    }

    func applyCompleteProtection(to url: URL) throws {
        try requireContained(url)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    func moveWithoutOverwriting(from source: URL, to destination: URL) throws {
        try requireContained(source)
        try requireContained(destination)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw PhotographFileStoreError.destinationExists
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func removeManagedFile(at url: URL) throws {
        try requireContained(url)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw PhotographFileStoreError.expectedRegularFile
        }
        try FileManager.default.removeItem(at: url)
    }

    func inspectAllEntries() throws -> PhotographFileInspection {
        var inspection = PhotographFileInspection()
        try inspectCanonicalDirectory(into: &inspection)
        try inspectOperationDirectory(
            temporaryDirectoryURL,
            expectedExtension: PhotographConstants.temporaryExtension,
            kind: .temporary,
            into: &inspection
        )
        try inspectOperationDirectory(
            quarantineDirectoryURL,
            expectedExtension: PhotographConstants.jpegExtension,
            kind: .quarantine,
            into: &inspection
        )
        return inspection
    }

    func availableCapacityForImportantUsage() throws -> Int64? {
        let values = try rootURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return values.volumeAvailableCapacityForImportantUsage
    }

    func canonicalFileIsAvailable(for id: UUID) throws -> Bool {
        let url = canonicalURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        return try isManagedRegularFile(url)
    }

    private func inspectCanonicalDirectory(
        into inspection: inout PhotographFileInspection
    ) throws {
        let entries = try contents(of: rootURL)
        for entry in entries {
            if entry == temporaryDirectoryURL || entry == quarantineDirectoryURL {
                continue
            }
            guard try isManagedRegularFile(entry),
                  let id = parseCanonicalFilename(entry.lastPathComponent)
            else {
                inspection.unknownEntries.append(entry)
                continue
            }
            inspection.canonicalFiles[id] = entry
        }
    }

    private enum OperationKind {
        case temporary
        case quarantine
    }

    private func inspectOperationDirectory(
        _ directory: URL,
        expectedExtension: String,
        kind: OperationKind,
        into inspection: inout PhotographFileInspection
    ) throws {
        for entry in try contents(of: directory) {
            guard try isManagedRegularFile(entry),
                  let parsed = parseOperationFilename(
                    entry.lastPathComponent,
                    expectedExtension: expectedExtension
                  )
            else {
                inspection.unknownEntries.append(entry)
                continue
            }
            let file = ManagedOperationFile(
                photoID: parsed.photoID,
                operationID: parsed.operationID,
                url: entry
            )
            switch kind {
            case .temporary:
                inspection.temporaryFiles.append(file)
            case .quarantine:
                inspection.quarantineFiles[parsed.photoID, default: []].append(file)
            }
        }
    }

    private func contents(of directory: URL) throws -> [URL] {
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw PhotographFileStoreError.directoryUnavailable
        }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: []
        )
    }

    private func isManagedRegularFile(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func parseCanonicalFilename(_ filename: String) -> UUID? {
        let suffix = ".\(PhotographConstants.jpegExtension)"
        guard filename.hasSuffix(suffix) else { return nil }
        let rawID = String(filename.dropLast(suffix.count))
        guard rawID == rawID.lowercased(), let id = UUID(uuidString: rawID) else {
            return nil
        }
        return id
    }

    private func parseOperationFilename(
        _ filename: String,
        expectedExtension: String
    ) -> (photoID: UUID, operationID: UUID)? {
        let components = filename.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components[2] == Substring(expectedExtension)
        else {
            return nil
        }
        let rawPhotoID = String(components[0])
        let rawOperationID = String(components[1])
        guard
            rawPhotoID == rawPhotoID.lowercased(),
            rawOperationID == rawOperationID.lowercased(),
            let photoID = UUID(uuidString: rawPhotoID),
            let operationID = UUID(uuidString: rawOperationID)
        else {
            return nil
        }
        return (photoID, operationID)
    }

    private func requireContained(_ url: URL) throws {
        let rootPath = rootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        guard candidatePath == rootPath || candidatePath.hasPrefix("\(rootPath)/") else {
            throw PhotographFileStoreError.unmanagedURL
        }
    }
}
