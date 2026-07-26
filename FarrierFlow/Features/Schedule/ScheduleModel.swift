import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ScheduleModel {
    private(set) var sections: [ScheduleSection] = []
    var alert: FeatureAlert?

    func load(in context: ModelContext, now: Date, calendar: Calendar) {
        let boundary = CalendarRules.scheduleBoundary(now: now, calendar: calendar)
        let descriptor = FetchDescriptor<Appointment>(
            predicate: #Predicate { $0.startDate >= boundary },
            sortBy: [SortDescriptor(\.startDate)]
        )

        do {
            let appointments = try context.fetch(descriptor)
            let grouped = Dictionary(grouping: appointments) {
                calendar.startOfDay(for: $0.startDate)
            }
            sections = grouped.keys.sorted().map {
                ScheduleSection(dayStart: $0, appointments: grouped[$0] ?? [])
            }
        } catch {
            sections = []
            alert = FeatureAlert(
                title: "Couldn’t Load Schedule",
                message: "FarrierFlow couldn’t load scheduled appointments."
            )
        }
    }
}
