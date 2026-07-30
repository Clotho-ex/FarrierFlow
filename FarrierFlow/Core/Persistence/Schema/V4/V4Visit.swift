import Foundation
import SwiftData

extension FarrierFlowSchemaV4 {
    @Model
    final class Visit {
        var startedAt: Date
        var completedAt: Date?
        var serviceLocationNameSnapshot: String
        var serviceLocationAddressSnapshot: String?
        var workItemPolicyVersion: Int = 0
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
            workItemPolicyVersion: Int = 0,
            appointment: Appointment,
            barn: Barn
        ) {
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.workItemPolicyVersion = workItemPolicyVersion
            self.appointment = appointment
            self.barn = barn
        }
    }
}
