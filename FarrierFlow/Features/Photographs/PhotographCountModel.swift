import Observation
import SwiftData

nonisolated enum PhotographCountState: Equatable, Sendable {
    case loading
    case loaded(Int)
    case unavailable
}

@MainActor
@Observable
final class PhotographCountModel {
    @ObservationIgnored private let loader: @MainActor (PersistentIdentifier) throws -> [PhotographItem]
    let visitHorseID: PersistentIdentifier
    private(set) var state: PhotographCountState = .loading

    init(
        visitHorseID: PersistentIdentifier,
        library: PhotographLibrary,
        loader: (@MainActor (PersistentIdentifier) throws -> [PhotographItem])? = nil
    ) {
        self.visitHorseID = visitHorseID
        self.loader = loader ?? { try library.items(for: $0) }
    }

    func load() {
        state = .loading
        do {
            state = .loaded(try loader(visitHorseID).count)
        } catch {
            state = .unavailable
        }
    }
}
