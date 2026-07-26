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

        for horse in horses {
            try validate(horse)
        }
        for appointmentHorse in appointmentHorses {
            try validate(appointmentHorse)
        }
        for appointment in appointments {
            try validate(
                appointment,
                memberships: appointmentHorses.filter {
                    $0.appointment === appointment
                }
            )
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

    private static func validate(
        _ appointment: Appointment,
        memberships: [AppointmentHorse]
    ) throws {
        guard let barn = appointment.barn else {
            throw DomainGraphViolation.appointmentMissingBarn
        }
        guard !memberships.isEmpty else {
            throw DomainGraphViolation.appointmentHasNoValidHorse
        }

        var horseIDs = Set<PersistentIdentifier>()
        for membership in memberships {
            guard let horse = membership.horse else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }
            guard horse.currentBarn === barn else {
                throw DomainGraphViolation.horseOutsideAppointmentBarn
            }
            guard horseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateHorseMembership
            }
        }
    }
}
