import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class Visit: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var startedAt: Date
        var completedAt: Date?
        var serviceLocationNameSnapshot: String
        var serviceLocationAddressSnapshot: String?
        var appointment: Appointment?
        var barn: Barn?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \VisitHorse.visit
        )
        var visitHorses: [VisitHorse] = []

        @Relationship(deleteRule: .deny, inverse: \InvoiceVisit.sourceVisit)
        var invoiceVisits: [InvoiceVisit] = []

        init(
            syncID: UUID = UUID(),
            startedAt: Date,
            completedAt: Date? = nil,
            serviceLocationNameSnapshot: String,
            serviceLocationAddressSnapshot: String? = nil,
            appointment: Appointment,
            barn: Barn
        ) {
            self.syncID = syncID
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.appointment = appointment
            self.barn = barn
        }
    }
}
