import Foundation
import SwiftData

nonisolated enum VisitSaveError: Error, Equatable {
    case visitUnavailable
    case visitIsCompleted
    case correctionRequiresCompletedVisit
    case completionPredatesStart
}

@MainActor
enum VisitSaveUseCase {
    static func editorMode(
        visitID: PersistentIdentifier,
        in context: ModelContext
    ) throws -> VisitEditorMode {
        guard let visit = try context.existingModel(Visit.self, for: visitID) else {
            throw VisitSaveError.visitUnavailable
        }
        return visit.completedAt == nil ? .inProgress : .correction
    }

    static func loadDraft(
        visitID: PersistentIdentifier,
        in context: ModelContext
    ) throws -> VisitDraft {
        guard let visit = try context.existingModel(Visit.self, for: visitID) else {
            throw VisitSaveError.visitUnavailable
        }
        try DomainGraphValidator.validateAll(in: context)

        let horses = try visit.visitHorses.map { visitHorse in
            guard visitHorse.visit === visit else {
                throw DomainGraphViolation.visitMembershipMismatch
            }
            guard let horse = visitHorse.horse else {
                throw DomainGraphViolation.visitHorseMissingHorse
            }
            guard let outcome = VisitOutcome(rawValue: visitHorse.outcomeRawValue) else {
                throw VisitDraftViolation.unknownOutcome
            }
            return VisitHorseDraft(
                id: visitHorse.persistentModelID,
                horseID: horse.persistentModelID,
                horseName: horse.name,
                outcome: outcome,
                workNotes: visitHorse.workNotes ?? ""
            )
        }

        guard !horses.isEmpty else {
            throw DomainGraphViolation.visitHasNoHorse
        }
        return VisitDraft(
            visitID: visitID,
            horses: horses.sorted { lhs, rhs in
                let comparison = lhs.horseName.localizedStandardCompare(rhs.horseName)
                if comparison == .orderedSame {
                    return String(describing: lhs.horseID) < String(describing: rhs.horseID)
                }
                return comparison == .orderedAscending
            }
        )
    }

    static func saveProgress(
        draft: VisitDraft,
        in context: ModelContext
    ) throws -> VisitDraft {
        try saveProgress(
            draft: draft,
            in: context,
            saving: { context in
                try DomainGraphValidator.save(context)
            }
        )
    }

    static func saveProgress(
        draft: VisitDraft,
        in context: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> VisitDraft {
        do {
            let visit = try resolveVisit(for: draft, in: context)
            try DomainGraphValidator.validateInProgress(visit)

            if let violation = VisitRules.progressViolation(in: draft) {
                throw violation
            }
            try apply(draft, to: visit, in: context)

            try saving(context)
            return try loadDraft(visitID: draft.visitID, in: context)
        } catch {
            // The Visit editor owns this context and keeps all user edits in its
            // draft, so rollback cannot discard unrelated screen mutations.
            context.rollback()
            throw error
        }
    }

    static func complete(
        draft: VisitDraft,
        completedAt: Date,
        in context: ModelContext
    ) throws -> VisitDraft {
        try complete(
            draft: draft,
            completedAt: completedAt,
            in: context,
            saving: { context in
                try DomainGraphValidator.save(context)
            }
        )
    }

    static func complete(
        draft: VisitDraft,
        completedAt: Date,
        in context: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> VisitDraft {
        do {
            let visit = try resolveVisit(for: draft, in: context)
            try DomainGraphValidator.validateInProgress(visit)
            if let violation = VisitRules.completionViolation(in: draft) {
                throw violation
            }
            guard completedAt >= visit.startedAt else {
                throw VisitSaveError.completionPredatesStart
            }

            try apply(draft, to: visit, in: context)
            visit.completedAt = completedAt
            try saving(context)
            return try loadDraft(visitID: draft.visitID, in: context)
        } catch {
            // A Visit editor owns its action context, so this removes every
            // failed completion mutation without touching another screen.
            context.rollback()
            throw error
        }
    }

    static func saveCorrection(
        draft: VisitDraft,
        in context: ModelContext
    ) throws -> VisitDraft {
        try saveCorrection(
            draft: draft,
            in: context,
            saving: { context in
                try DomainGraphValidator.save(context)
            }
        )
    }

    static func saveCorrection(
        draft: VisitDraft,
        in context: ModelContext,
        saving: (ModelContext) throws -> Void
    ) throws -> VisitDraft {
        do {
            let visit = try resolveVisit(for: draft, in: context)
            guard visit.completedAt != nil else {
                throw VisitSaveError.correctionRequiresCompletedVisit
            }
            if let violation = VisitRules.correctionViolation(in: draft) {
                throw violation
            }

            let immutableState = VisitImmutableState(visit: visit)
            try apply(draft, to: visit, in: context)
            guard immutableState.matches(visit) else {
                throw DomainGraphViolation.visitMembershipMismatch
            }
            try saving(context)
            return try loadDraft(visitID: draft.visitID, in: context)
        } catch {
            // Correction uses the same isolated Visit context as progress and
            // completion, which makes rollback safe and preserves the draft.
            context.rollback()
            throw error
        }
    }

    private static func resolveVisit(
        for draft: VisitDraft,
        in context: ModelContext
    ) throws -> Visit {
        guard let visit = try context.existingModel(Visit.self, for: draft.visitID) else {
            throw VisitSaveError.visitUnavailable
        }
        try DomainGraphValidator.validateAll(in: context)
        return visit
    }

    private static func apply(
        _ draft: VisitDraft,
        to visit: Visit,
        in context: ModelContext
    ) throws {
        let visitHorseIDs = Set(visit.visitHorses.map(\.persistentModelID))
        let draftVisitHorseIDs = Set(draft.horses.map(\.id))
        guard
            visitHorseIDs.count == visit.visitHorses.count,
            draftVisitHorseIDs.count == draft.horses.count,
            visitHorseIDs == draftVisitHorseIDs
        else {
            throw DomainGraphViolation.visitMembershipMismatch
        }

        for horseDraft in draft.horses {
            guard
                let visitHorse = try context.existingModel(VisitHorse.self, for: horseDraft.id),
                visitHorse.visit === visit,
                let horse = visitHorse.horse,
                horse.persistentModelID == horseDraft.horseID
            else {
                throw DomainGraphViolation.visitMembershipMismatch
            }

            visitHorse.outcomeRawValue = horseDraft.outcome.rawValue
            visitHorse.workNotes = TextNormalization.optional(horseDraft.workNotes)
        }
    }
}

private struct VisitImmutableState {
    let appointmentID: PersistentIdentifier?
    let barnID: PersistentIdentifier?
    let startedAt: Date
    let completedAt: Date?
    let serviceLocationNameSnapshot: String
    let serviceLocationAddressSnapshot: String?
    let visitHorseIDs: Set<PersistentIdentifier>

    init(visit: Visit) {
        appointmentID = visit.appointment?.persistentModelID
        barnID = visit.barn?.persistentModelID
        startedAt = visit.startedAt
        completedAt = visit.completedAt
        serviceLocationNameSnapshot = visit.serviceLocationNameSnapshot
        serviceLocationAddressSnapshot = visit.serviceLocationAddressSnapshot
        visitHorseIDs = Set(visit.visitHorses.map(\.persistentModelID))
    }

    func matches(_ visit: Visit) -> Bool {
        appointmentID == visit.appointment?.persistentModelID
            && barnID == visit.barn?.persistentModelID
            && startedAt == visit.startedAt
            && completedAt == visit.completedAt
            && serviceLocationNameSnapshot == visit.serviceLocationNameSnapshot
            && serviceLocationAddressSnapshot == visit.serviceLocationAddressSnapshot
            && visitHorseIDs == Set(visit.visitHorses.map(\.persistentModelID))
    }
}
