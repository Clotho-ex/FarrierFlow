nonisolated enum VisitDraftViolation: Error, Equatable {
    case unknownOutcome
    case duplicateHorse
    case workNotesRequireServicedOutcome
    case pendingOutcomePreventsCompletion
    case completionRequiresServicedHorse
}

nonisolated enum VisitRules {
    static func selectableOutcomes(for mode: VisitEditorMode) -> [VisitOutcome] {
        switch mode {
        case .inProgress:
            VisitOutcome.allCases
        case .correction:
            [.serviced, .notServiced]
        }
    }

    static func outcome(for rawValue: String) -> Result<VisitOutcome, VisitDraftViolation> {
        guard let outcome = VisitOutcome(rawValue: rawValue) else {
            return .failure(.unknownOutcome)
        }
        return .success(outcome)
    }

    static func progressViolation(in draft: VisitDraft) -> VisitDraftViolation? {
        guard Set(draft.horses.map(\.horseID)).count == draft.horses.count else {
            return .duplicateHorse
        }
        guard draft.horses.allSatisfy({ horse in
            horse.outcome == .serviced || TextNormalization.optional(horse.workNotes) == nil
        }) else {
            return .workNotesRequireServicedOutcome
        }
        return nil
    }

    static func completionViolation(in draft: VisitDraft) -> VisitDraftViolation? {
        if let violation = progressViolation(in: draft) {
            return violation
        }
        guard !draft.horses.contains(where: { $0.outcome == .pending }) else {
            return .pendingOutcomePreventsCompletion
        }
        guard draft.horses.contains(where: { $0.outcome == .serviced }) else {
            return .completionRequiresServicedHorse
        }
        return nil
    }

    static func correctionViolation(in draft: VisitDraft) -> VisitDraftViolation? {
        completionViolation(in: draft)
    }

    static func requiresWorkNotesClearConfirmation(
        from draft: VisitHorseDraft,
        to outcome: VisitOutcome
    ) -> Bool {
        draft.outcome == .serviced
            && TextNormalization.optional(draft.workNotes) != nil
            && outcome != .serviced
    }
}
