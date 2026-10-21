import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StopDetailsModel {
    private(set) var stop: TodayStopSummary?
    private(set) var loadState: TodayLoadState = .loading
    private var selectedID: TodayStopSummary.ID
    private var appointmentIDs: [PersistentIdentifier]

    init(stop: TodayStopSummary) {
        selectedID = stop.id
        appointmentIDs = stop.appointments.map(\.id)
    }

    func load(in container: ModelContainer) {
        let context = ModelContext(container)
        do {
            if let current = try stop(matching: selectedID, in: context) {
                apply(current)
            } else {
                // Keep the original physical stop while it still has appointments.
                // Follow a moved record only when that stop no longer exists.
                var movedStop: TodayStopSummary?
                for id in appointmentIDs {
                    guard let appointment = try context.existingModel(Appointment.self, for: id) else { continue }
                    let summary = try TodayAppointmentSummary.project(appointment)
                    let id = TodayStopSummary.ID(
                        serviceLocationID: summary.serviceLocationID,
                        startDate: summary.startDate,
                        state: summary.state
                    )
                    movedStop = try stop(matching: id, in: context)
                    if movedStop != nil { break }
                }
                if let movedStop { apply(movedStop) } else { stop = nil }
            }
            loadState = .loaded
        } catch {
            stop = nil
            loadState = .failed
        }
    }

    private func apply(_ stop: TodayStopSummary) {
        self.stop = stop
        selectedID = stop.id
        appointmentIDs = stop.appointments.map(\.id)
    }

    private func stop(matching id: TodayStopSummary.ID, in context: ModelContext) throws -> TodayStopSummary? {
        let startDate = id.startDate
        let records = try context.fetch(FetchDescriptor<Appointment>(
            predicate: #Predicate { $0.startDate == startDate }
        ))
        let summaries = try records
            .filter { $0.barn?.persistentModelID == id.serviceLocationID }
            .map(TodayAppointmentSummary.project)
            .sorted { left, right in
                let names = left.horseNames.joined(separator: ", ").localizedStandardCompare(right.horseNames.joined(separator: ", "))
                if names != .orderedSame { return names == .orderedAscending }
                return String(describing: left.id) < String(describing: right.id)
            }
        return TodayStopSummary.grouped(summaries).first { $0.id == id }
    }
}
