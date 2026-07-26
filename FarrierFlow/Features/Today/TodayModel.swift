import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TodayModel {
    private(set) var appointments: [Appointment] = []
    var alert: FeatureAlert?

    func load(in context: ModelContext, now: Date, calendar: Calendar) {
        let interval = CalendarRules.dayInterval(containing: now, calendar: calendar)
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<Appointment>(
            predicate: #Predicate {
                $0.startDate >= start && $0.startDate < end
            },
            sortBy: [SortDescriptor(\.startDate)]
        )

        do {
            appointments = try context.fetch(descriptor)
        } catch {
            appointments = []
            alert = FeatureAlert(
                title: "Couldn’t Load Today",
                message: "FarrierFlow couldn’t load today’s appointments."
            )
        }
    }
}
