import SwiftData

nonisolated enum DomainGraphViolation: Error, Equatable {
    case horseMissingClient
    case horseMissingCurrentBarn
    case appointmentMissingBarn
    case appointmentHasNoValidHorse
    case appointmentHorseMissingAppointment
    case appointmentHorseMissingHorse
    case horseOutsideAppointmentBarn
    case duplicateHorseMembership
    case visitMissingAppointment
    case visitMissingBarn
    case visitHasNoHorse
    case visitHorseMissingVisit
    case visitHorseMissingHorse
    case duplicateVisitHorseMembership
    case visitMembershipMismatch
    case visitLocationNameMissing
    case inProgressVisitHasCompletionDate
    case completedVisitHasPendingHorse
    case completedVisitHasNoServicedHorse
    case completionPredatesStart
    case workNotesRequireServicedOutcome
    case appointmentVisitMismatch
}

@MainActor
enum DomainGraphValidator {
    static func save(_ context: ModelContext) throws {
        try validateAll(in: context)
        try context.save()
    }

    static func validateAll(in context: ModelContext) throws {
        let horses = try context.fetch(FetchDescriptor<Horse>())
        let appointments = try context.fetch(FetchDescriptor<Appointment>())
        let appointmentHorses = try context.fetch(FetchDescriptor<AppointmentHorse>())
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let visitHorses = try context.fetch(FetchDescriptor<VisitHorse>())

        for horse in horses {
            try validate(horse)
        }

        var appointmentMemberships = [PersistentIdentifier: [AppointmentHorse]]()
        for appointmentHorse in appointmentHorses {
            try validate(appointmentHorse)
            if let appointment = appointmentHorse.appointment {
                appointmentMemberships[appointment.persistentModelID, default: []]
                    .append(appointmentHorse)
            }
        }

        var visitMemberships = [PersistentIdentifier: [VisitHorse]]()
        for visitHorse in visitHorses {
            try validate(visitHorse)
            if let visit = visitHorse.visit {
                visitMemberships[visit.persistentModelID, default: []].append(visitHorse)
            }
        }

        var visitsByAppointment = [PersistentIdentifier: [Visit]]()
        for visit in visits {
            if let appointment = visit.appointment {
                visitsByAppointment[appointment.persistentModelID, default: []].append(visit)
            }
            try validate(
                visit,
                memberships: visitMemberships[visit.persistentModelID, default: []],
                appointmentMemberships: &appointmentMemberships
            )
        }

        for appointment in appointments {
            try validate(
                appointment,
                memberships: appointmentMemberships[appointment.persistentModelID, default: []],
                visits: visitsByAppointment[appointment.persistentModelID, default: []]
            )
        }
    }

    static func validateInProgress(_ visit: Visit) throws {
        guard visit.completedAt == nil else {
            throw DomainGraphViolation.inProgressVisitHasCompletionDate
        }
    }

    private static func validate(_ horse: Horse) throws {
        guard horse.client != nil else {
            throw DomainGraphViolation.horseMissingClient
        }
        guard horse.currentBarn != nil else {
            throw DomainGraphViolation.horseMissingCurrentBarn
        }
    }

    private static func validate(_ appointmentHorse: AppointmentHorse) throws {
        guard appointmentHorse.appointment != nil else {
            throw DomainGraphViolation.appointmentHorseMissingAppointment
        }
        guard appointmentHorse.horse != nil else {
            throw DomainGraphViolation.appointmentHorseMissingHorse
        }
    }

    private static func validate(_ visitHorse: VisitHorse) throws {
        guard visitHorse.visit != nil else {
            throw DomainGraphViolation.visitHorseMissingVisit
        }
        guard visitHorse.horse != nil else {
            throw DomainGraphViolation.visitHorseMissingHorse
        }
    }

    private static func validate(
        _ appointment: Appointment,
        memberships: [AppointmentHorse],
        visits: [Visit]
    ) throws {
        guard let barn = appointment.barn else {
            throw DomainGraphViolation.appointmentMissingBarn
        }
        guard !memberships.isEmpty else {
            throw DomainGraphViolation.appointmentHasNoValidHorse
        }
        guard visits.count <= 1 else {
            throw DomainGraphViolation.appointmentVisitMismatch
        }

        let visit = appointment.visit
        if let visit {
            guard visit.appointment === appointment, visits.first === visit else {
                throw DomainGraphViolation.appointmentVisitMismatch
            }
        } else if !visits.isEmpty {
            throw DomainGraphViolation.appointmentVisitMismatch
        }

        var horseIDs = Set<PersistentIdentifier>()
        for membership in memberships {
            guard let horse = membership.horse else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }
            if visit?.completedAt == nil, horse.currentBarn !== barn {
                throw DomainGraphViolation.horseOutsideAppointmentBarn
            }
            guard horseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateHorseMembership
            }
        }
    }

    private static func validate(
        _ visit: Visit,
        memberships: [VisitHorse],
        appointmentMemberships: inout [PersistentIdentifier: [AppointmentHorse]]
    ) throws {
        guard let appointment = visit.appointment else {
            throw DomainGraphViolation.visitMissingAppointment
        }
        guard let barn = visit.barn else {
            throw DomainGraphViolation.visitMissingBarn
        }
        guard appointment.visit === visit, appointment.barn === barn else {
            throw DomainGraphViolation.appointmentVisitMismatch
        }
        guard TextNormalization.required(visit.serviceLocationNameSnapshot) != nil else {
            throw DomainGraphViolation.visitLocationNameMissing
        }
        guard !memberships.isEmpty else {
            throw DomainGraphViolation.visitHasNoHorse
        }

        let appointmentHorseIDs = try Set(
            appointmentMemberships[appointment.persistentModelID, default: []].map { membership in
                guard let horse = membership.horse else {
                    throw DomainGraphViolation.appointmentHorseMissingHorse
                }
                return horse.persistentModelID
            }
        )

        var visitHorseIDs = Set<PersistentIdentifier>()
        var hasPendingHorse = false
        var hasServicedHorse = false
        for membership in memberships {
            guard let horse = membership.horse else {
                throw DomainGraphViolation.visitHorseMissingHorse
            }
            guard visitHorseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateVisitHorseMembership
            }

            guard let outcome = VisitOutcome(rawValue: membership.outcomeRawValue) else {
                throw DomainGraphViolation.visitMembershipMismatch
            }
            if TextNormalization.optional(membership.workNotes ?? "") != nil,
               outcome != .serviced {
                throw DomainGraphViolation.workNotesRequireServicedOutcome
            }
            hasPendingHorse = hasPendingHorse || outcome == .pending
            hasServicedHorse = hasServicedHorse || outcome == .serviced
        }

        guard visitHorseIDs == appointmentHorseIDs else {
            throw DomainGraphViolation.visitMembershipMismatch
        }

        if let completedAt = visit.completedAt {
            guard completedAt >= visit.startedAt else {
                throw DomainGraphViolation.completionPredatesStart
            }
            guard !hasPendingHorse else {
                throw DomainGraphViolation.completedVisitHasPendingHorse
            }
            guard hasServicedHorse else {
                throw DomainGraphViolation.completedVisitHasNoServicedHorse
            }
        }
    }
}
