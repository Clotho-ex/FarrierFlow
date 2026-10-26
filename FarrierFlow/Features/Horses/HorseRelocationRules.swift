import Foundation
import SwiftData

nonisolated enum AppointmentVisitState: Equatable, Sendable {
    case noVisit
    case inProgress
    case completed
    case invalid
}

nonisolated struct HorseRelocationProjection: Equatable {
    let appointmentStates: [AppointmentVisitState]
    let hasInProgressVisitHorse: Bool
    let isSameBarn: Bool
}

struct HorseRelocationConfirmation: Equatable {
    let horseID: PersistentIdentifier
    let sourceID: PersistentIdentifier
    let destinationID: PersistentIdentifier
    let horseName: String
    let sourceName: String
    let destinationName: String

    @MainActor
    init?(horse: Horse, destination: Barn) {
        guard let source = horse.currentBarn, source !== destination else { return nil }
        horseID = horse.persistentModelID
        sourceID = source.persistentModelID
        destinationID = destination.persistentModelID
        horseName = horse.name
        sourceName = source.name
        destinationName = destination.name
    }

    var alert: FeatureAlert {
        FeatureAlert(
            title: "Move to Another Location?",
            message: "Move \(horseName) from \(sourceName) to \(destinationName)? Completed visit history will keep its original location."
        )
    }
}

nonisolated enum HorseRelocationRules {
    static func canRelocate(
        appointmentStates: [AppointmentVisitState],
        hasInProgressVisitHorse: Bool,
        isSameBarn: Bool
    ) -> Bool {
        if isSameBarn {
            return true
        }
        guard !hasInProgressVisitHorse else {
            return false
        }
        return appointmentStates.allSatisfy { $0 == .completed }
    }

    @MainActor
    static func projection(
        for horse: Horse,
        destinationBarnID: PersistentIdentifier
    ) -> HorseRelocationProjection? {
        guard let currentBarnID = horse.currentBarn?.persistentModelID else {
            return nil
        }

        let visitHorseStates = horse.visitHorses.map(visitState(for:))
        let invalidVisitHorseState = visitHorseStates.contains(.invalid)
        var appointmentStates = horse.appointmentHorses.map(appointmentVisitState(for:))
        if invalidVisitHorseState {
            appointmentStates.append(.invalid)
        }

        return HorseRelocationProjection(
            appointmentStates: appointmentStates,
            hasInProgressVisitHorse: visitHorseStates.contains(.inProgress),
            isSameBarn: currentBarnID == destinationBarnID
        )
    }

    @MainActor
    static func appointmentVisitState(
        for membership: AppointmentHorse
    ) -> AppointmentVisitState {
        guard
            let appointment = membership.appointment,
            appointment.appointmentHorses.contains(where: { $0 === membership }),
            membership.horse != nil
        else {
            return .invalid
        }
        guard let visit = appointment.visit else {
            return .noVisit
        }
        guard isValidVisit(visit, for: appointment) else {
            return .invalid
        }
        return visit.completedAt == nil ? .inProgress : .completed
    }

    @MainActor
    private static func visitState(
        for membership: VisitHorse
    ) -> AppointmentVisitState {
        guard
            let visit = membership.visit,
            membership.horse != nil,
            visit.visitHorses.contains(where: { $0 === membership }),
            isValidVisit(visit)
        else {
            return .invalid
        }
        return visit.completedAt == nil ? .inProgress : .completed
    }

    private static func isValidVisit(
        _ visit: Visit,
        for expectedAppointment: Appointment? = nil
    ) -> Bool {
        guard
            let visitBarn = visit.barn,
            TextNormalization.required(visit.serviceLocationNameSnapshot) != nil,
            !visit.visitHorses.isEmpty
        else {
            return false
        }

        let appointment = visit.appointment
        if let expectedAppointment, appointment !== expectedAppointment { return false }
        if let appointment {
            guard appointment.visit === visit, appointment.barn === visitBarn,
                  !appointment.appointmentHorses.isEmpty else { return false }
        }
        var appointmentHorseIDs = Set<PersistentIdentifier>()
        for membership in appointment?.appointmentHorses ?? [] {
            guard
                membership.appointment === appointment,
                let horse = membership.horse,
                horse.client != nil,
                horse.currentBarn != nil,
                appointmentHorseIDs.insert(horse.persistentModelID).inserted
            else {
                return false
            }
        }

        var visitHorseIDs = Set<PersistentIdentifier>()
        var hasPendingOutcome = false
        for membership in visit.visitHorses {
            guard
                membership.visit === visit,
                let horse = membership.horse,
                horse.client != nil,
                horse.currentBarn != nil,
                visitHorseIDs.insert(horse.persistentModelID).inserted,
                let outcome = VisitOutcome(rawValue: membership.outcomeRawValue),
                TextNormalization.optional(membership.workNotes ?? "") == nil
                    || outcome == .serviced
            else {
                return false
            }
            hasPendingOutcome = hasPendingOutcome || outcome == .pending
        }

        if appointment != nil, visitHorseIDs != appointmentHorseIDs {
            return false
        }

        if let completedAt = visit.completedAt {
            return completedAt >= visit.startedAt
                && !hasPendingOutcome
        }

        return visit.visitHorses.allSatisfy { $0.horse?.currentBarn === visitBarn }
    }
}
