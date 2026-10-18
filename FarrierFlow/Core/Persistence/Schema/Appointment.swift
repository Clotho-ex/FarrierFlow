import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class Appointment: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var startDate: Date
        var notes: String?
        var expectedDurationMinutes: Int?
        var barn: Barn?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \AppointmentHorse.appointment
        )
        var appointmentHorses: [AppointmentHorse] = []

        @Relationship(deleteRule: .deny, inverse: \Visit.appointment)
        var visit: Visit?

        init(
            syncID: UUID = UUID(),
            startDate: Date,
            notes: String? = nil,
            expectedDurationMinutes: Int? = nil,
            barn: Barn
        ) {
            self.syncID = syncID
            self.startDate = startDate
            self.notes = notes
            self.expectedDurationMinutes = expectedDurationMinutes
            self.barn = barn
        }
    }
}
