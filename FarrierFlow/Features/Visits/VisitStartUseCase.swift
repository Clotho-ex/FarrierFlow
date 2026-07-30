import Foundation
import SwiftData

nonisolated enum VisitStartError: Error, Equatable {
    case appointmentUnavailable
    case visitAlreadyExists
    case serviceLocationUnavailable
}

@MainActor
enum VisitStartUseCase {
    static func start(
        appointmentID: PersistentIdentifier,
        now: Date,
        in container: ModelContainer
    ) throws -> PersistentIdentifier {
        try start(
            appointmentID: appointmentID,
            now: now,
            in: container,
            actionContext: ModelContext(container),
            saving: { context in
                try DomainGraphValidator.save(context)
            }
        )
    }

    static func start(
        appointmentID: PersistentIdentifier,
        now: Date,
        in container: ModelContainer,
        saving: (ModelContext) throws -> Void
    ) throws -> PersistentIdentifier {
        try start(
            appointmentID: appointmentID,
            now: now,
            in: container,
            actionContext: ModelContext(container),
            saving: saving
        )
    }

    static func start(
        appointmentID: PersistentIdentifier,
        now: Date,
        in _: ModelContainer,
        actionContext: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> PersistentIdentifier {
        let context = actionContext

        do {
            guard let appointment = try context.existingModel(
                Appointment.self,
                for: appointmentID
            ) else {
                throw VisitStartError.appointmentUnavailable
            }
            try DomainGraphValidator.validateAll(in: context)
            guard appointment.visit == nil else {
                throw VisitStartError.visitAlreadyExists
            }
            guard
                let barn = appointment.barn,
                let serviceLocationNameSnapshot = TextNormalization.required(barn.name)
            else {
                throw VisitStartError.serviceLocationUnavailable
            }

            let serviceLocationAddressSnapshot = TextNormalization.optional(barn.address ?? "")
            let horses = appointment.appointmentHorses.compactMap(\.horse)
            guard horses.count == appointment.appointmentHorses.count else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }

            let visit = Visit(
                startedAt: now,
                serviceLocationNameSnapshot: serviceLocationNameSnapshot,
                serviceLocationAddressSnapshot: serviceLocationAddressSnapshot,
                appointment: appointment,
                barn: barn
            )
            context.insert(visit)
            appointment.visit = visit
            barn.visits.append(visit)

            for horse in horses {
                let visitHorse = VisitHorse(
                    outcomeRawValue: VisitOutcome.pending.rawValue,
                    visit: visit,
                    horse: horse
                )
                context.insert(visitHorse)
                visit.visitHorses.append(visitHorse)
                horse.visitHorses.append(visitHorse)

                if let service = horse.defaultService {
                    guard
                        let serviceNameSnapshot = TextNormalization.required(service.name),
                        !visitHorse.workItems.contains(where: { $0.service === service })
                    else {
                        throw DomainGraphViolation.duplicateWorkItemService
                    }

                    let workItem = WorkItem(
                        serviceNameSnapshot: serviceNameSnapshot,
                        amountMinorUnits: service.defaultAmountMinorUnits,
                        currencyCode: "USD",
                        service: service,
                        visitHorse: visitHorse
                    )
                    context.insert(workItem)
                    service.workItems.append(workItem)
                    visitHorse.workItems.append(workItem)
                }
            }

            try saving(context)
            return visit.persistentModelID
        } catch {
            context.rollback()
            throw error
        }
    }
}
