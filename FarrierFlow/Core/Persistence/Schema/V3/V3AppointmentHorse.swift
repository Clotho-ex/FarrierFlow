import SwiftData

extension FarrierFlowSchemaV3 {
    @Model
    final class AppointmentHorse {
        var appointment: Appointment?
        var horse: Horse?

        init(appointment: Appointment, horse: Horse) {
            self.appointment = appointment
            self.horse = horse
        }
    }
}
