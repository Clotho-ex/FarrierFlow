import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class AppointmentHorse: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var appointment: Appointment?
        var horse: Horse?
        var plannedService: Service?

        init(syncID: UUID = UUID(), appointment: Appointment, horse: Horse) {
            self.syncID = syncID
            self.appointment = appointment
            self.horse = horse
        }
    }
}
