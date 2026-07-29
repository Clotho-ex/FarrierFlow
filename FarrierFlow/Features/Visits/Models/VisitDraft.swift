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
    let workItemPolicyVersion: Int
    var horses: [VisitHorseDraft]

    init(
        visitID: PersistentIdentifier,
        workItemPolicyVersion: Int = 0,
        horses: [VisitHorseDraft]
    ) {
        self.visitID = visitID
        self.workItemPolicyVersion = workItemPolicyVersion
        self.horses = horses
    }
}
