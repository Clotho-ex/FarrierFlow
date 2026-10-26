import Foundation
import SwiftData

struct AppointmentRowSummary {
    enum State: Equatable {
        case scheduled
        case inProgress
        case completed

        var title: LocalizedStringResource {
            switch self {
            case .scheduled: "Scheduled"
            case .inProgress: "In Progress"
            case .completed: "Completed"
            }
        }
    }

    let barnName: String
    let horseDetail: String
    let plannedServices: String?
    let state: State

    init(appointment: Appointment) {
        barnName = appointment.barn?.name ?? String(localized: "Service location unavailable")
        state = appointment.visit.map {
            $0.completedAt == nil ? .inProgress : .completed
        } ?? .scheduled

        let memberships = appointment.appointmentHorses
        let horses = memberships.compactMap(\.horse)
        if horses.count == 1, let horse = horses.first {
            horseDetail = horse.client.map { String(localized: "\(horse.name) · \($0.name)") }
                ?? horse.name
        } else if horses.isEmpty {
            horseDetail = String(localized: "Horse unavailable")
        } else {
            let count = String(localized: "\(horses.count) horses")
            let clients = Dictionary(grouping: horses.compactMap(\.client), by: \.persistentModelID)
            if horses.allSatisfy({ $0.client != nil }), !clients.isEmpty {
                if clients.count == 1, let owner = clients.values.first?.first {
                    horseDetail = String(localized: "\(count) · \(owner.name)")
                } else {
                    let owners = String(localized: "\(clients.count) clients")
                    horseDetail = String(localized: "\(count) · \(owners)")
                }
            } else {
                horseDetail = count
            }
        }

        // Appointment plans describe this booking; saved horse defaults are not a plan.
        guard state != .completed else {
            plannedServices = nil
            return
        }
        let plans = memberships.compactMap(\.plannedService)
        let names = Set(plans.map(\.name)).sorted(using: String.StandardComparator(.localizedStandard))
        guard !names.isEmpty else {
            plannedServices = nil
            return
        }
        var visibleNames = Array(names.prefix(2))
        if names.count > 2 {
            visibleNames.append(String(localized: "\(names.count - 2) more"))
        }
        let services = visibleNames.formatted(.list(type: .and))
        if plans.count < horses.count {
            let coverage = String(localized: "\(plans.count) of \(horses.count) horses")
            plannedServices = String(localized: "\(services) · \(coverage)")
        } else {
            plannedServices = services
        }
    }
}
