import SwiftData

extension FarrierFlowSchemaV2 {
    @Model
    final class VisitHorse {
        var outcomeRawValue: String
        var workNotes: String?
        var visit: Visit?
        var horse: Horse?

        init(
            outcomeRawValue: String = "pending",
            workNotes: String? = nil,
            visit: Visit,
            horse: Horse
        ) {
            self.outcomeRawValue = outcomeRawValue
            self.workNotes = workNotes
            self.visit = visit
            self.horse = horse
        }
    }
}
