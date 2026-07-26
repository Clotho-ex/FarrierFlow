import Foundation
import SwiftData

nonisolated enum RecordDeletionBlock: Error, Equatable {
    case clientHasHorses
    case barnHasHorses
    case barnHasAppointments
    case barnHasHorsesAndAppointments
    case horseHasAppointments

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
        case .horseHasAppointments:
            FeatureAlert(
                title: "Can’t Delete Horse",
                message: "Delete appointments that reference this horse first."
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
        guard horse.appointmentHorses.isEmpty else {
            throw RecordDeletionBlock.horseHasAppointments
        }
        try persistDeletion(in: context) {
            context.delete(horse)
        }
    }

    static func delete(_ appointment: Appointment, in context: ModelContext) throws {
        try persistDeletion(in: context) {
            context.delete(appointment)
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
