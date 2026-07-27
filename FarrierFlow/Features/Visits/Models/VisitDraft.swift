import SwiftData

nonisolated struct VisitHorseDraft: Equatable, Identifiable {
    let id: PersistentIdentifier
    let horseID: PersistentIdentifier
    let horseName: String
    var outcome: VisitOutcome
    var workNotes: String
}

nonisolated struct VisitDraft: Equatable {
    let visitID: PersistentIdentifier
    var horses: [VisitHorseDraft]
}
