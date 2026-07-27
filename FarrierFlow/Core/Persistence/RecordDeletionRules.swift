import Foundation
import SwiftData

nonisolated enum RecordDeletionBlock: Error, Equatable {
    case clientHasHorses
    case barnHasHorses
    case barnHasAppointments
    case barnHasHorsesAndAppointments
    case barnHasVisits
    case horseHasAppointments
    case horseHasVisits
    case appointmentHasVisit
    case completedVisitCannotBeDeleted

    var alert: FeatureAlert {
        switch self {
        case .clientHasHorses:
            FeatureAlert(
                title: "Can’t Delete Client",
                message: "Reassign or remove this client’s horses first."
            )
        case .barnHasHorses:
            FeatureAlert(
                title: "Can’t Delete Service Location",
                message: "Move or remove the horses at this service location first."
            )
        case .barnHasAppointments:
            FeatureAlert(
                title: "Can’t Delete Service Location",
                message: "Delete its appointments first."
            )
        case .barnHasHorsesAndAppointments:
            FeatureAlert(
                title: "Can’t Delete Service Location",
                message: "Move or remove its horses and delete its appointments first."
            )
        case .barnHasVisits:
            FeatureAlert(
                title: "Can’t Delete Service Location",
                message: "This service location is referenced by visit history."
            )
        case .horseHasAppointments:
            FeatureAlert(
                title: "Can’t Delete Horse",
                message: "Delete appointments that reference this horse first."
            )
        case .horseHasVisits:
            FeatureAlert(
                title: "Can’t Delete Horse",
                message: "This horse is referenced by visit history."
            )
        case .appointmentHasVisit:
            FeatureAlert(
                title: "Can’t Delete Appointment",
                message: "This appointment has a visit."
            )
        case .completedVisitCannotBeDeleted:
            FeatureAlert(
                title: "Can’t Delete Visit",
                message: "Completed visits remain part of horse history."
            )
        }
    }
}

@MainActor
enum RecordDeletionRules {
    static func delete(_ client: Client, in context: ModelContext) throws {
        guard client.horses.isEmpty else { throw RecordDeletionBlock.clientHasHorses }
        try persistDeletion(in: context) {
            context.delete(client)
        }
    }

    static func delete(_ barn: Barn, in context: ModelContext) throws {
        if !barn.visits.isEmpty {
            throw RecordDeletionBlock.barnHasVisits
        }
        switch (barn.horses.isEmpty, barn.appointments.isEmpty) {
        case (false, false):
            throw RecordDeletionBlock.barnHasHorsesAndAppointments
        case (false, true):
            throw RecordDeletionBlock.barnHasHorses
        case (true, false):
            throw RecordDeletionBlock.barnHasAppointments
        case (true, true):
            try persistDeletion(in: context) {
                context.delete(barn)
            }
        }
    }

    static func delete(_ horse: Horse, in context: ModelContext) throws {
        if !horse.visitHorses.isEmpty {
            throw RecordDeletionBlock.horseHasVisits
        }
        guard horse.appointmentHorses.isEmpty else {
            throw RecordDeletionBlock.horseHasAppointments
        }
        try persistDeletion(in: context) {
            context.delete(horse)
        }
    }

    static func delete(_ appointment: Appointment, in context: ModelContext) throws {
        guard appointment.visit == nil else {
            throw RecordDeletionBlock.appointmentHasVisit
        }
        try persistDeletion(in: context) {
            context.delete(appointment)
        }
    }

    static func delete(_ visit: Visit, in context: ModelContext) throws {
        guard visit.completedAt == nil else {
            throw RecordDeletionBlock.completedVisitCannotBeDeleted
        }
        try persistDeletion(in: context) {
            let appointment = visit.appointment
            let barn = visit.barn
            appointment?.visit = nil
            visit.appointment = nil
            barn?.visits.removeAll { $0 === visit }
            visit.barn = nil
            context.delete(visit)
        }
    }

    static func delete(
        _ appointmentHorse: AppointmentHorse,
        in context: ModelContext
    ) throws {
        try persistDeletion(in: context) {
            context.delete(appointmentHorse)
        }
    }

    private static func persistDeletion(
        in context: ModelContext,
        _ mutation: () -> Void
    ) throws {
        mutation()
        do {
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
