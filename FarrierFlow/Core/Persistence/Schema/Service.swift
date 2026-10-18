import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class Service: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var name: String
        var defaultAmountMinorUnits: Int64
        var currencyCode: String
        var isArchived: Bool

        @Relationship(deleteRule: .deny, inverse: \Horse.defaultService)
        var horsesUsingAsDefault: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \WorkItem.service)
        var workItems: [WorkItem] = []

        @Relationship(deleteRule: .deny, inverse: \AppointmentHorse.plannedService)
        var plannedAppointments: [AppointmentHorse] = []

        init(
            syncID: UUID = UUID(),
            name: String,
            defaultAmountMinorUnits: Int64,
            currencyCode: String = "USD",
            isArchived: Bool = false
        ) {
            self.syncID = syncID
            self.name = name
            self.defaultAmountMinorUnits = defaultAmountMinorUnits
            self.currencyCode = currencyCode
            self.isArchived = isArchived
        }
    }
}
