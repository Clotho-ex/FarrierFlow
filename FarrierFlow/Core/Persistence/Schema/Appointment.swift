import Foundation
import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class Appointment {
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

        init(
            startDate: Date,
            notes: String? = nil,
            expectedDurationMinutes: Int? = nil,
            barn: Barn
        ) {
            self.startDate = startDate
            self.notes = notes
            self.expectedDurationMinutes = expectedDurationMinutes
            self.barn = barn
        }
    }
}
