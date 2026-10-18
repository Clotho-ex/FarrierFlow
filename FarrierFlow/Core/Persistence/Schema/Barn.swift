import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class Barn: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var name: String
        var address: String?
        var contactNotes: String?

        @Relationship(deleteRule: .deny, inverse: \Horse.currentBarn)
        var horses: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \Appointment.barn)
        var appointments: [Appointment] = []

        @Relationship(deleteRule: .deny, inverse: \Visit.barn)
        var visits: [Visit] = []

        init(
            syncID: UUID = UUID(),
            name: String,
            address: String? = nil,
            contactNotes: String? = nil
        ) {
            self.syncID = syncID
            self.name = name
            self.address = address
            self.contactNotes = contactNotes
        }
    }
}
