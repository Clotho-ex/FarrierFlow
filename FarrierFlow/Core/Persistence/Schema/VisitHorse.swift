import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class VisitHorse: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var outcomeRawValue: String
        var workNotes: String?
        var visit: Visit?
        var horse: Horse?

        @Relationship(deleteRule: .cascade, inverse: \Photograph.visitHorse)
        var photographs: [Photograph] = []

        @Relationship(deleteRule: .cascade, inverse: \WorkItem.visitHorse)
        var workItems: [WorkItem] = []

        init(
            syncID: UUID = UUID(),
            outcomeRawValue: String = "pending",
            workNotes: String? = nil,
            visit: Visit,
            horse: Horse
        ) {
            self.syncID = syncID
            self.outcomeRawValue = outcomeRawValue
            self.workNotes = workNotes
            self.visit = visit
            self.horse = horse
        }
    }
}
