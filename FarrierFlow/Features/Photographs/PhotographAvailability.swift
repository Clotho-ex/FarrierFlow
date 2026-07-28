import Foundation

nonisolated enum PhotographAvailability: Equatable, Sendable {
    case available
    case unavailable
}

nonisolated struct PhotographItem: Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int64
    let availability: PhotographAvailability
}
