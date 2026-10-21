import Foundation
import SwiftData

// Copy linked records while their context is valid, just like the detail values.
struct RecordUsageSnapshot: Equatable {
    struct AppointmentReference: Equatable, Identifiable {
        let id: PersistentIdentifier
        let startDate: Date
        let location: String
        let horseNames: [String]
    }

    struct VisitReference: Equatable, Identifiable {
        let id: PersistentIdentifier
        let startedAt: Date
        let location: String
        let horseNames: [String]
        let serviceNames: [String]
        let isCompleted: Bool
        let invoiceNumbers: [String]
    }

    var appointments: [AppointmentReference] = []
    var visits: [VisitReference] = []

    init() {}

    init(horse: Horse) throws {
        appointments = try Self.appointments(from: horse.appointmentHorses)
        visits = try Self.visits(from: horse.visitHorses, serviceID: nil)
    }

    init(service: Service) throws {
        appointments = try Self.appointments(from: service.plannedAppointments, includingStarted: true)
        let memberships = try service.workItems.map { item in
            guard let membership = item.visitHorse else { throw UsageError.missingRelationship }
            return membership
        }
        visits = try Self.visits(from: memberships, serviceID: service.persistentModelID)
    }

    private static func appointments(
        from memberships: [AppointmentHorse],
        includingStarted: Bool = false
    ) throws -> [AppointmentReference] {
        var records: [PersistentIdentifier: AppointmentReference] = [:]
        for membership in memberships {
            guard let appointment = membership.appointment, let barn = appointment.barn else {
                throw UsageError.missingRelationship
            }
            // Horse history already shows started visits. Services can also be
            // referenced by a planned choice before any work is recorded.
            guard includingStarted || appointment.visit == nil else { continue }
            records[appointment.persistentModelID] = AppointmentReference(
                id: appointment.persistentModelID,
                startDate: appointment.startDate,
                location: barn.name,
                horseNames: try appointment.appointmentHorses.map {
                    guard let horse = $0.horse else { throw UsageError.missingRelationship }
                    return horse.name
                }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            )
        }
        return records.values.sorted {
            $0.startDate == $1.startDate ? $0.id < $1.id : $0.startDate < $1.startDate
        }
    }

    private static func visits(
        from memberships: [VisitHorse],
        serviceID: PersistentIdentifier?
    ) throws -> [VisitReference] {
        var grouped: [PersistentIdentifier: [PersistentIdentifier: VisitHorse]] = [:]
        for membership in memberships {
            guard let visit = membership.visit else { throw UsageError.missingRelationship }
            grouped[visit.persistentModelID, default: [:]][membership.persistentModelID] = membership
        }
        return try grouped.map { id, members in
            guard let visit = members.values.first?.visit else { throw UsageError.missingRelationship }
            let work = members.values.flatMap(\.workItems).filter {
                serviceID == nil || $0.service?.persistentModelID == serviceID
            }
            return VisitReference(
                id: id,
                startedAt: visit.startedAt,
                location: visit.serviceLocationNameSnapshot,
                horseNames: try members.values.map {
                    guard let horse = $0.horse else { throw UsageError.missingRelationship }
                    return horse.name
                }.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                serviceNames: work.map(\.serviceNameSnapshot)
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                isCompleted: visit.completedAt != nil,
                invoiceNumbers: try Array(Set(work.compactMap { $0.invoiceLineItem?.invoiceVisit?.invoice?.number }))
                    .sorted().map(InvoiceDomainRules.formattedNumber)
            )
        }.sorted {
            $0.startedAt == $1.startedAt ? $0.id < $1.id : $0.startedAt > $1.startedAt
        }
    }

    private enum UsageError: Error {
        case missingRelationship
    }
}
