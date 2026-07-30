import Foundation
import SwiftData

nonisolated enum RecordDeletionBlock: Error, Equatable {
    case clientHasHorses
    case clientHasInvoices
    case barnHasHorses
    case barnHasAppointments
    case barnHasHorsesAndAppointments
    case barnHasVisits
    case horseHasAppointments
    case horseHasVisits
    case appointmentHasVisit
    case completedVisitCannotBeDeleted
    case visitHasInvoiceLineItems
    case workItemHasInvoiceLineItem
    case businessProfileCannotBeDeleted
    case serviceHasHorseDefaults
    case serviceHasWorkItems
    case serviceHasHorseDefaultsAndWorkItems

    var alert: FeatureAlert {
        switch self {
        case .clientHasHorses:
            FeatureAlert(
                title: "Can’t Delete Client",
                message: "Reassign or remove this client’s horses first."
            )
        case .clientHasInvoices:
            FeatureAlert(
                title: "Can’t Delete Client",
                message: "This client is referenced by invoice history."
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
        case .visitHasInvoiceLineItems:
            FeatureAlert(
                title: "Can’t Delete Visit",
                message: "This visit is referenced by an invoice."
            )
        case .workItemHasInvoiceLineItem:
            FeatureAlert(
                title: "Can’t Delete Recorded Work",
                message: "This recorded work is referenced by an invoice."
            )
        case .businessProfileCannotBeDeleted:
            FeatureAlert(
                title: "Can’t Delete Business Profile",
                message: "Edit the existing business profile instead."
            )
        case .serviceHasHorseDefaults:
            FeatureAlert(
                title: "Can’t Delete Service",
                message: "Clear or replace every Horse default first."
            )
        case .serviceHasWorkItems:
            FeatureAlert(
                title: "Can’t Delete Service",
                message: "This service is referenced by recorded work."
            )
        case .serviceHasHorseDefaultsAndWorkItems:
            FeatureAlert(
                title: "Can’t Delete Service",
                message: "Clear Horse defaults and remove recorded work first."
            )
        }
    }
}

@MainActor
enum RecordDeletionRules {
    static func delete(_ client: Client, in context: ModelContext) throws {
        guard client.invoices.isEmpty else { throw RecordDeletionBlock.clientHasInvoices }
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
        guard visit.invoiceVisits.isEmpty else {
            throw RecordDeletionBlock.visitHasInvoiceLineItems
        }
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
        switch (service.horsesUsingAsDefault.isEmpty, service.workItems.isEmpty) {
        case (false, false):
            throw RecordDeletionBlock.serviceHasHorseDefaultsAndWorkItems
        case (false, true):
            throw RecordDeletionBlock.serviceHasHorseDefaults
        case (true, false):
            throw RecordDeletionBlock.serviceHasWorkItems
        case (true, true):
            try persistDeletion(in: context) {
                context.delete(service)
            }
        }
    }

    static func delete(_ workItem: WorkItem, in context: ModelContext) throws {
        guard workItem.invoiceLineItem == nil else {
            throw RecordDeletionBlock.workItemHasInvoiceLineItem
        }
        try persistDeletion(in: context) {
            workItem.service?.workItems.removeAll { $0 === workItem }
            workItem.visitHorse?.workItems.removeAll { $0 === workItem }
            context.delete(workItem)
        }
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
