import Foundation
import SwiftData

extension FarrierFlowSchemaV3 {
    @Model
    final class Visit {
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

        init(
            startedAt: Date,
            completedAt: Date? = nil,
            serviceLocationNameSnapshot: String,
            serviceLocationAddressSnapshot: String? = nil,
            appointment: Appointment,
            barn: Barn
        ) {
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.appointment = appointment
            self.barn = barn
        }
    }
}
