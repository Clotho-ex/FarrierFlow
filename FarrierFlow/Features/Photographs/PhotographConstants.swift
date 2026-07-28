import Foundation

nonisolated enum PhotographConstants {
    static let rootDirectoryName = "HoofPhotographs"
    static let temporaryDirectoryName = "Temporary"
    static let quarantineDirectoryName = "Quarantine"
    static let jpegExtension = "jpg"
    static let temporaryExtension = "tmp"
    static let maximumLongestEdge = 2_560
    static let jpegQuality = 0.82
    static let maximumPhotographsPerVisitHorse = 16

    static func filename(for id: UUID) -> String {
        "\(id.uuidString.lowercased()).\(jpegExtension)"
    }

    static func operationFilename(
        photoID: UUID,
        operationID: UUID,
        extension fileExtension: String
    ) -> String {
        "\(photoID.uuidString.lowercased()).\(operationID.uuidString.lowercased()).\(fileExtension)"
    }
}
