import Foundation

struct ScheduleSection: Identifiable {
    let dayStart: Date
    let appointments: [ScheduleAppointment]

    var id: Date { dayStart }
}
