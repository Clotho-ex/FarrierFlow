import Foundation
import SwiftData

nonisolated struct HorseHistoryEntry: Identifiable, Equatable {
    let id: PersistentIdentifier
    let visitID: PersistentIdentifier
    let horseName: String
    let startedAt: Date
    let completedAt: Date
    let serviceLocationName: String
    let outcome: VisitOutcome
    let hasWorkNotes: Bool
}

nonisolated struct HorseHistoryRecord: Equatable {
    let id: PersistentIdentifier
    let visitID: PersistentIdentifier
    let horseID: PersistentIdentifier
    let horseName: String
    let startedAt: Date
    let completedAt: Date?
    let serviceLocationName: String
    let outcomeRawValue: String
    let workNotes: String?
}

nonisolated enum HorseHistoryLoadState: Equatable {
    case loading
    case loaded
    case failed
}

nonisolated enum HorseHistoryLoadError: Error, Equatable {
    case horseUnavailable
    case invalidHistory
}
