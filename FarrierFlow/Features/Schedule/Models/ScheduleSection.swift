import Foundation

nonisolated struct ScheduleSection: Identifiable {
    let dayStart: Date
    let appointments: [Appointment]

    var id: Date { dayStart }
}
