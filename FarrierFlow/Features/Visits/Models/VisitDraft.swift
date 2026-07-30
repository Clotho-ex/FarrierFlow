import SwiftData

nonisolated struct VisitHorseDraft: Equatable, Identifiable {
    let id: PersistentIdentifier
    let horseID: PersistentIdentifier
    let horseName: String
    var outcome: VisitOutcome
    var workNotes: String
    var workItems: [WorkItemDraft] = []
}

nonisolated struct VisitDraft: Equatable {
    let visitID: PersistentIdentifier
    var horses: [VisitHorseDraft]

    init(
        visitID: PersistentIdentifier,
        horses: [VisitHorseDraft]
    ) {
        self.visitID = visitID
        self.horses = horses
    }
}
