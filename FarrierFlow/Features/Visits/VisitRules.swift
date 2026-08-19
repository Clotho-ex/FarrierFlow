import SwiftData

nonisolated enum VisitDraftViolation: Error, Equatable {
    case unknownOutcome
    case duplicateHorse
    case workNotesRequireServicedOutcome
    case notServicedHorseHasWorkItems
    case invalidWorkItem(WorkItemDraftViolation)
    case pendingOutcomePreventsCompletion
    case completionRequiresServicedHorse
    case servicedHorseRequiresWorkItem
}

nonisolated enum VisitBatchWorkViolation: Error, Equatable {
    case targetSelectionRequired
    case duplicateTarget
    case sourceSelectedAsTarget
    case sourceHorseUnavailable
    case sourceMustBeServiced
    case sourceRequiresRecordedWork
    case invalidSourceWork(WorkItemDraftViolation)
    case sourceContainsArchivedService
    case targetHorseUnavailable
    case targetMustBePending
    case targetHasWorkNotes
    case targetHasRecordedWork
    case invalidResult(VisitDraftViolation)
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
        for horse in draft.horses {
            if horse.outcome == .notServiced, !horse.workItems.isEmpty {
                return .notServicedHorseHasWorkItems
            }
            if let violation = WorkItemRules.violation(in: horse.workItems) {
                return .invalidWorkItem(violation)
            }
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
        guard draft.horses.allSatisfy({
            $0.outcome != .serviced || !$0.workItems.isEmpty
        }) else {
            return .servicedHorseRequiresWorkItem
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
        draft.outcome != .notServiced
            && outcome == .notServiced
            && (
                TextNormalization.optional(draft.workNotes) != nil
                    || !draft.workItems.isEmpty
            )
    }

    static func batchSourceViolation(
        for horse: VisitHorseDraft
    ) -> VisitBatchWorkViolation? {
        guard horse.outcome == .serviced else {
            return .sourceMustBeServiced
        }
        guard !horse.workItems.isEmpty else {
            return .sourceRequiresRecordedWork
        }
        if let violation = WorkItemRules.violation(in: horse.workItems) {
            return .invalidSourceWork(violation)
        }
        guard horse.workItems.allSatisfy({ !$0.serviceIsArchived }) else {
            return .sourceContainsArchivedService
        }
        return nil
    }

    static func batchTargetViolation(
        for horse: VisitHorseDraft
    ) -> VisitBatchWorkViolation? {
        guard horse.outcome == .pending else {
            return .targetMustBePending
        }
        guard TextNormalization.optional(horse.workNotes) == nil else {
            return .targetHasWorkNotes
        }
        guard horse.workItems.isEmpty else {
            return .targetHasRecordedWork
        }
        return nil
    }

    static func applyingRecordedWork(
        from sourceID: PersistentIdentifier,
        to targetIDs: [PersistentIdentifier],
        in draft: VisitDraft
    ) -> Result<VisitDraft, VisitBatchWorkViolation> {
        guard !targetIDs.isEmpty else {
            return .failure(.targetSelectionRequired)
        }
        guard Set(targetIDs).count == targetIDs.count else {
            return .failure(.duplicateTarget)
        }
        guard !targetIDs.contains(sourceID) else {
            return .failure(.sourceSelectedAsTarget)
        }
        guard let source = draft.horses.first(where: { $0.id == sourceID }) else {
            return .failure(.sourceHorseUnavailable)
        }
        if let violation = batchSourceViolation(for: source) {
            return .failure(violation)
        }

        var updated = draft
        for targetID in targetIDs {
            guard let targetIndex = updated.horses.firstIndex(where: { $0.id == targetID }) else {
                return .failure(.targetHorseUnavailable)
            }
            if let violation = batchTargetViolation(for: updated.horses[targetIndex]) {
                return .failure(violation)
            }
            updated.horses[targetIndex].outcome = .serviced
            updated.horses[targetIndex].workItems = source.workItems.map { workItem in
                WorkItemDraft(
                    serviceID: workItem.serviceID,
                    serviceNameSnapshot: workItem.serviceNameSnapshot,
                    amountMinorUnits: workItem.amountMinorUnits,
                    currencyCode: workItem.currencyCode,
                    serviceIsArchived: workItem.serviceIsArchived
                )
            }
        }

        if let violation = progressViolation(in: updated) {
            return .failure(.invalidResult(violation))
        }
        return .success(updated)
    }
}
