import Foundation

nonisolated enum PhotographCollectionLoadState: Equatable, Sendable {
    case loading
    case loaded
    case failed
}
