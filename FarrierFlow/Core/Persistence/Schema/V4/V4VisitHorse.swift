import SwiftData

extension FarrierFlowSchemaV4 {
    @Model
    final class VisitHorse {
        var outcomeRawValue: String
        var workNotes: String?
        var visit: Visit?
        var horse: Horse?

        @Relationship(deleteRule: .cascade, inverse: \Photograph.visitHorse)
        var photographs: [Photograph] = []

        @Relationship(deleteRule: .cascade, inverse: \WorkItem.visitHorse)
        var workItems: [WorkItem] = []

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
