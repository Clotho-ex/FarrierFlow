import Foundation

enum TemporaryStoreFixtures {
    static func makeDirectory(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let staleDirectories = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix(prefix) }

        for directory in staleDirectories {
            try? FileManager.default.removeItem(at: directory)
        }

        let directory = root.appending(
            path: "\(prefix)\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
