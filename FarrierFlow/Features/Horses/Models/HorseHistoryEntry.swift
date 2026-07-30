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
    let workItemCount: Int?
    let subtotal: MoneyAvailability

    init(
        id: PersistentIdentifier,
        visitID: PersistentIdentifier,
        horseName: String,
        startedAt: Date,
        completedAt: Date,
        serviceLocationName: String,
        outcome: VisitOutcome,
        hasWorkNotes: Bool,
        workItemCount: Int? = nil,
        subtotal: MoneyAvailability = .unavailable
    ) {
        self.id = id
        self.visitID = visitID
        self.horseName = horseName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.serviceLocationName = serviceLocationName
        self.outcome = outcome
        self.hasWorkNotes = hasWorkNotes
        self.workItemCount = workItemCount
        self.subtotal = subtotal
    }
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
    let workItemCount: Int?
    let subtotal: MoneyAvailability

    init(
        id: PersistentIdentifier,
        visitID: PersistentIdentifier,
        horseID: PersistentIdentifier,
        horseName: String,
        startedAt: Date,
        completedAt: Date?,
        serviceLocationName: String,
        outcomeRawValue: String,
        workNotes: String?,
        workItemCount: Int? = nil,
        subtotal: MoneyAvailability = .unavailable
    ) {
        self.id = id
        self.visitID = visitID
        self.horseID = horseID
        self.horseName = horseName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.serviceLocationName = serviceLocationName
        self.outcomeRawValue = outcomeRawValue
        self.workNotes = workNotes
        self.workItemCount = workItemCount
        self.subtotal = subtotal
    }
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
