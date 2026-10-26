import Foundation
import Observation
import SwiftData

nonisolated enum ScheduleScope: Hashable {
    case scheduled, completed
}

struct ScheduleAppointment: Identifiable {
    let id: PersistentIdentifier
    let startDate: Date
    let summary: AppointmentRowSummary
    let serviceIDs: Set<PersistentIdentifier>
}

@MainActor
@Observable
final class ScheduleModel {
    private(set) var sections: [ScheduleSection] = []
    private(set) var services: [ServiceChoice] = []
    var alert: FeatureAlert?

    func load(
        in context: ModelContext,
        now: Date,
        calendar: Calendar,
        scope: ScheduleScope = .scheduled,
        serviceID: PersistentIdentifier? = nil
    ) {
        let boundary = CalendarRules.scheduleBoundary(now: now, calendar: calendar)
        let predicate: Predicate<Appointment> = scope == .completed
            ? #Predicate { $0.visit?.completedAt != nil }
            : #Predicate { $0.startDate >= boundary && $0.visit?.completedAt == nil }
        let descriptor = FetchDescriptor<Appointment>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate)]
        )

        do {
            // Visits are saved in separate contexts. Copy fresh values so retained rows
            // cannot keep a stale appointment-to-visit inverse after work is completed.
            let readContext = ModelContext(context.container)
            let appointments = try readContext.fetch(descriptor)
            var choices: [PersistentIdentifier: ServiceChoice] = [:]
            let rows = appointments.map { appointment in
                let referencedServices = scope == .completed
                    ? appointment.visit?.visitHorses.flatMap(\.workItems).compactMap(\.service) ?? []
                    : appointment.appointmentHorses.compactMap(\.plannedService)
                for service in referencedServices {
                    choices[service.persistentModelID] = ServiceChoice(
                        id: service.persistentModelID, name: service.name,
                        defaultAmountMinorUnits: service.defaultAmountMinorUnits,
                        currencyCode: service.currencyCode
                    )
                }
                return ScheduleAppointment(
                    id: appointment.persistentModelID,
                    startDate: appointment.startDate,
                    summary: AppointmentRowSummary(appointment: appointment),
                    serviceIDs: Set(referencedServices.map(\.persistentModelID))
                )
            }
            services = choices.values.sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                if order != .orderedSame { return order == .orderedAscending }
                if $0.defaultAmountMinorUnits != $1.defaultAmountMinorUnits {
                    return $0.defaultAmountMinorUnits < $1.defaultAmountMinorUnits
                }
                return $0.id < $1.id
            }
            let filtered = rows.filter { row in serviceID.map { row.serviceIDs.contains($0) } ?? true }
            let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.startDate) }
            let days = scope == .completed ? grouped.keys.sorted(by: >) : grouped.keys.sorted()
            sections = days.map { day in
                let appointments = grouped[day] ?? []
                return ScheduleSection(dayStart: day, appointments: scope == .completed ? Array(appointments.reversed()) : appointments)
            }
            alert = nil
        } catch {
            sections = []
            services = []
            alert = FeatureAlert(
                title: "Couldn’t Load Schedule",
                message: "FarrierFlow couldn’t load scheduled appointments."
            )
        }
    }
}
