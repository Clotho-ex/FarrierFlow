import SwiftData

extension FarrierFlowSchemaV4 {
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
