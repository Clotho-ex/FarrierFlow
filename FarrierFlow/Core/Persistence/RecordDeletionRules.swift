import Foundation
import SwiftData

nonisolated enum RecordDeletionBlock: Error, Equatable {
    case businessProfileCannotBeDeleted
    case serviceHasHorseDefaults

    var alert: FeatureAlert {
        switch self {
        case .businessProfileCannotBeDeleted:
            FeatureAlert(title: "Can’t Delete Business Profile", message: "Edit the existing business profile instead.")
        case .serviceHasHorseDefaults:
            FeatureAlert(title: "Can’t Archive Service", message: "Clear or replace every Horse default first.")
        }
    }
}

@MainActor
enum RecordDeletionRules {
    static func delete(_ client: Client, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.client(client.persistentModelID), in: context)
    }

    static func delete(_ barn: Barn, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.barn(barn.persistentModelID), in: context)
    }

    static func delete(_ horse: Horse, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.horse(horse.persistentModelID), in: context)
    }

    static func delete(_ appointment: Appointment, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.appointment(appointment.persistentModelID), in: context)
    }

    static func delete(_ visit: Visit, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.visit(visit.persistentModelID), in: context)
    }

    static func delete(
        _ appointmentHorse: AppointmentHorse,
        in context: ModelContext
    ) throws {
        try persistDeletion(in: context) {
            context.delete(appointmentHorse)
        }
    }

    static func archive(_ service: Service, in context: ModelContext) throws {
        guard service.horsesUsingAsDefault.isEmpty else {
            throw RecordDeletionBlock.serviceHasHorseDefaults
        }
        service.isArchived = true
        do {
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func delete(_ service: Service, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.service(service.persistentModelID), in: context)
    }

    static func delete(_ workItem: WorkItem, in context: ModelContext) throws {
        try RecordDeletionPlan.execute(.workItem(workItem.persistentModelID), in: context)
    }

    static func delete(
        _ businessProfile: BusinessProfile,
        in context: ModelContext
    ) throws {
        throw RecordDeletionBlock.businessProfileCannotBeDeleted
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
