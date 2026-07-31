import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum VisitEditorLoadState: Equatable {
    case loading
    case loaded
    case failed
}

nonisolated struct VisitOutcomeChange: Equatable {
    let visitHorseID: PersistentIdentifier
    let outcome: VisitOutcome
}

nonisolated enum VisitEditorMode: Equatable {
    case inProgress
    case correction
}

nonisolated enum VisitAddServiceRequest: Equatable {
    case createService
    case chooseService
    case serviceAdded
}

@MainActor
@Observable
final class VisitEditorModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "VisitEditor"
    )

    @ObservationIgnored
    private let context: ModelContext
    @ObservationIgnored
    private let loading: (PersistentIdentifier, ModelContext) throws -> VisitDraft
    @ObservationIgnored
    private let saving: (VisitDraft, ModelContext) throws -> VisitDraft
    @ObservationIgnored
    private let completing: (VisitDraft, Date, ModelContext) throws -> VisitDraft
    @ObservationIgnored
    private let correcting: (VisitDraft, ModelContext) throws -> VisitDraft

    private(set) var loadState: VisitEditorLoadState = .loading
    private(set) var lastSavedDraft: VisitDraft?
    var draft: VisitDraft?
    private(set) var pendingOutcomeChange: VisitOutcomeChange?
    private var backgroundSaveErrorPending = false
    var alert: FeatureAlert?

    let visitID: PersistentIdentifier
    let mode: VisitEditorMode

    var isDirty: Bool {
        draft != lastSavedDraft
    }

    var canSaveProgress: Bool {
        guard mode == .inProgress, loadState == .loaded, let draft else { return false }
        return VisitRules.progressViolation(in: draft) == nil
    }

    var canComplete: Bool {
        guard mode == .inProgress, loadState == .loaded, let draft else { return false }
        return VisitRules.completionViolation(in: draft) == nil
    }

    var canSaveCorrection: Bool {
        guard mode == .correction, loadState == .loaded, let draft else { return false }
        return VisitRules.correctionViolation(in: draft) == nil
    }

    init(
        visitID: PersistentIdentifier,
        in container: ModelContainer,
        mode: VisitEditorMode = .inProgress,
        loading: @escaping (PersistentIdentifier, ModelContext) throws -> VisitDraft = {
            try VisitEditorModel.loadDraft(visitID: $0, in: $1)
        },
        saving: @escaping (VisitDraft, ModelContext) throws -> VisitDraft = {
            try VisitSaveUseCase.saveProgress(draft: $0, in: $1)
        },
        completing: @escaping (VisitDraft, Date, ModelContext) throws -> VisitDraft = {
            try VisitSaveUseCase.complete(draft: $0, completedAt: $1, in: $2)
        },
        correcting: @escaping (VisitDraft, ModelContext) throws -> VisitDraft = {
            try VisitSaveUseCase.saveCorrection(draft: $0, in: $1)
        }
    ) {
        self.visitID = visitID
        self.mode = mode
        context = ModelContext(container)
        self.loading = loading
        self.saving = saving
        self.completing = completing
        self.correcting = correcting
    }

    func load() {
        loadState = .loading
        do {
            let storedMode = try VisitSaveUseCase.editorMode(visitID: visitID, in: context)
            guard storedMode == mode else {
                throw VisitSaveError.visitUnavailable
            }
            let loadedDraft = try loading(visitID, context)
            draft = loadedDraft
            lastSavedDraft = loadedDraft
            alert = nil
            loadState = .loaded
        } catch {
            loadState = .failed
            Self.logger.error("Failed to load visit editor: \(error, privacy: .public)")
            alert = FeatureAlert(
                title: "Visit Unavailable",
                message: "The visit couldn’t be loaded. Try again."
            )
        }
    }

    func retry() {
        load()
    }

    func requestOutcomeChange(
        for visitHorseID: PersistentIdentifier,
        to outcome: VisitOutcome
    ) -> Bool {
        guard
            let currentDraft = draft,
            let horse = currentDraft.horses.first(where: { $0.id == visitHorseID })
        else {
            return false
        }

        if VisitRules.requiresWorkNotesClearConfirmation(from: horse, to: outcome) {
            pendingOutcomeChange = VisitOutcomeChange(
                visitHorseID: visitHorseID,
                outcome: outcome
            )
            return true
        }

        applyOutcomeChange(for: visitHorseID, to: outcome)
        return false
    }

    func confirmPendingOutcomeChange() {
        guard let pendingOutcomeChange else { return }
        applyOutcomeChange(
            for: pendingOutcomeChange.visitHorseID,
            to: pendingOutcomeChange.outcome
        )
        self.pendingOutcomeChange = nil
    }

    func cancelPendingOutcomeChange() {
        pendingOutcomeChange = nil
    }

    func setWorkNotes(_ workNotes: String, for visitHorseID: PersistentIdentifier) {
        guard var updatedDraft = draft,
              let index = updatedDraft.horses.firstIndex(where: { $0.id == visitHorseID })
        else {
            return
        }
        updatedDraft.horses[index].workNotes = workNotes
        draft = updatedDraft
    }

    func eligibleServices(
        for visitHorseID: PersistentIdentifier,
        replacing workItemID: UUID? = nil
    ) -> [ServiceChoice] {
        guard let horse = draft?.horses.first(where: { $0.id == visitHorseID }) else {
            return []
        }
        do {
            let services = try context.fetch(FetchDescriptor<Service>())
            let usedServiceIDs = Set(
                horse.workItems
                    .filter { $0.id != workItemID }
                    .map(\.serviceID)
            )
            return ServiceRules.activeChoices(services).filter { !usedServiceIDs.contains($0.id) }
        } catch {
            Self.logger.error("Failed to load Services: \(error, privacy: .public)")
            return []
        }
    }

    func requestAddService(
        to visitHorseID: PersistentIdentifier
    ) -> VisitAddServiceRequest {
        let services = eligibleServices(for: visitHorseID)
        switch services.count {
        case 0:
            return .createService
        case 1:
            return addService(services[0], to: visitHorseID)
                ? .serviceAdded
                : .chooseService
        default:
            return .chooseService
        }
    }

    @discardableResult
    func addService(
        _ serviceID: PersistentIdentifier,
        to visitHorseID: PersistentIdentifier
    ) -> Bool {
        guard
            let service = eligibleServices(for: visitHorseID).first(where: { $0.id == serviceID })
        else {
            return false
        }

        return addService(service, to: visitHorseID)
    }

    private func addService(
        _ service: ServiceChoice,
        to visitHorseID: PersistentIdentifier
    ) -> Bool {
        guard
            var updatedDraft = draft,
            let horseIndex = updatedDraft.horses.firstIndex(where: { $0.id == visitHorseID })
        else {
            return false
        }

        updatedDraft.horses[horseIndex].workItems.append(
            WorkItemDraft(
                serviceID: service.id,
                serviceNameSnapshot: service.name,
                amountMinorUnits: service.defaultAmountMinorUnits,
                currencyCode: service.currencyCode
            )
        )
        updatedDraft.horses[horseIndex].workItems = WorkItemRules.sorted(
            updatedDraft.horses[horseIndex].workItems
        )
        draft = updatedDraft
        return true
    }

    @discardableResult
    func removeWorkItem(
        _ workItemID: UUID,
        from visitHorseID: PersistentIdentifier
    ) -> Bool {
        guard
            var updatedDraft = draft,
            let horseIndex = updatedDraft.horses.firstIndex(where: { $0.id == visitHorseID }),
            let workItemIndex = updatedDraft.horses[horseIndex].workItems.firstIndex(
                where: { $0.id == workItemID }
            )
        else {
            return false
        }
        updatedDraft.horses[horseIndex].workItems.remove(at: workItemIndex)
        draft = updatedDraft
        return true
    }

    @discardableResult
    func replaceWorkItem(
        _ workItemID: UUID,
        with serviceID: PersistentIdentifier,
        for visitHorseID: PersistentIdentifier
    ) -> Bool {
        guard
            var updatedDraft = draft,
            let horseIndex = updatedDraft.horses.firstIndex(where: { $0.id == visitHorseID }),
            let workItemIndex = updatedDraft.horses[horseIndex].workItems.firstIndex(
                where: { $0.id == workItemID }
            ),
            let service = eligibleServices(for: visitHorseID, replacing: workItemID)
                .first(where: { $0.id == serviceID }),
            updatedDraft.horses[horseIndex].workItems[workItemIndex].serviceID != serviceID
        else {
            return false
        }

        updatedDraft.horses[horseIndex].workItems[workItemIndex].serviceID = service.id
        updatedDraft.horses[horseIndex].workItems[workItemIndex].serviceNameSnapshot = service.name
        updatedDraft.horses[horseIndex].workItems[workItemIndex].amountMinorUnits = service.defaultAmountMinorUnits
        updatedDraft.horses[horseIndex].workItems = WorkItemRules.sorted(
            updatedDraft.horses[horseIndex].workItems
        )
        draft = updatedDraft
        return true
    }

    func isValidPriceInput(_ input: String) -> Bool {
        (try? USDPriceParser.parse(input)) != nil
    }

    @discardableResult
    func updateWorkItem(
        _ workItemID: UUID,
        serviceID: PersistentIdentifier,
        priceInput: String,
        for visitHorseID: PersistentIdentifier
    ) -> Bool {
        guard let amountMinorUnits = try? USDPriceParser.parse(priceInput) else {
            return false
        }
        guard
            var updatedDraft = draft,
            let horseIndex = updatedDraft.horses.firstIndex(where: { $0.id == visitHorseID }),
            let workItemIndex = updatedDraft.horses[horseIndex].workItems.firstIndex(
                where: { $0.id == workItemID }
            )
        else {
            return false
        }

        let current = updatedDraft.horses[horseIndex].workItems[workItemIndex]
        if current.serviceID != serviceID {
            guard replaceWorkItem(workItemID, with: serviceID, for: visitHorseID) else {
                return false
            }
            guard
                var replacedDraft = draft,
                let replacedHorseIndex = replacedDraft.horses.firstIndex(where: { $0.id == visitHorseID }),
                let replacedWorkItemIndex = replacedDraft.horses[replacedHorseIndex].workItems.firstIndex(
                    where: { $0.id == workItemID }
                )
            else {
                return false
            }
            replacedDraft.horses[replacedHorseIndex].workItems[replacedWorkItemIndex].amountMinorUnits = amountMinorUnits
            draft = replacedDraft
            return true
        }

        updatedDraft.horses[horseIndex].workItems[workItemIndex].amountMinorUnits = amountMinorUnits
        draft = updatedDraft
        return true
    }

    func discardUnsavedChanges() {
        draft = lastSavedDraft
        pendingOutcomeChange = nil
    }

    @discardableResult
    func saveProgress() -> Bool {
        guard let draft, canSaveProgress else {
            return false
        }

        return saveProgress(draft: draft, surfacesFailureImmediately: true)
    }

    @discardableResult
    func saveProgressForBackground() -> Bool {
        guard let draft, canSaveProgress else {
            return false
        }

        return saveProgress(draft: draft, surfacesFailureImmediately: false)
    }

    func surfacePendingBackgroundSaveErrorIfNeeded() {
        guard backgroundSaveErrorPending else { return }
        backgroundSaveErrorPending = false
        alert = saveErrorAlert
    }

    @discardableResult
    func completeVisit(at completedAt: Date = .now) -> Bool {
        guard let draft, canComplete else {
            return false
        }

        do {
            let savedDraft = try completing(draft, completedAt, context)
            self.draft = savedDraft
            lastSavedDraft = savedDraft
            alert = nil
            return true
        } catch {
            Self.logger.error("Failed to complete visit: \(error, privacy: .public)")
            alert = FeatureAlert(
                title: "Couldn’t Complete Visit",
                message: "Your changes are still in the visit. Try completing it again."
            )
            return false
        }
    }

    @discardableResult
    func saveCorrection() -> Bool {
        guard let draft, canSaveCorrection else {
            return false
        }

        do {
            let savedDraft = try correcting(draft, context)
            self.draft = savedDraft
            lastSavedDraft = savedDraft
            alert = nil
            return true
        } catch {
            Self.logger.error("Failed to save visit correction: \(error, privacy: .public)")
            alert = FeatureAlert(
                title: "Couldn’t Save Changes",
                message: "Your changes are still in the visit. Try saving again."
            )
            return false
        }
    }

    static func loadDraft(
        visitID: PersistentIdentifier,
        in context: ModelContext
    ) throws -> VisitDraft {
        try VisitSaveUseCase.loadDraft(visitID: visitID, in: context)
    }

    private func applyOutcomeChange(
        for visitHorseID: PersistentIdentifier,
        to outcome: VisitOutcome
    ) {
        guard var updatedDraft = draft,
              let index = updatedDraft.horses.firstIndex(where: { $0.id == visitHorseID })
        else {
            return
        }
        updatedDraft.horses[index].outcome = outcome
        if outcome != .serviced {
            updatedDraft.horses[index].workNotes = ""
        }
        if outcome == .notServiced {
            updatedDraft.horses[index].workItems = []
        }
        draft = updatedDraft
    }

    @discardableResult
    private func saveProgress(
        draft: VisitDraft,
        surfacesFailureImmediately: Bool
    ) -> Bool {
        do {
            let savedDraft = try saving(draft, context)
            self.draft = savedDraft
            lastSavedDraft = savedDraft
            backgroundSaveErrorPending = false
            alert = nil
            return true
        } catch {
            Self.logger.error("Failed to save visit progress: \(error, privacy: .public)")
            if surfacesFailureImmediately {
                alert = saveErrorAlert
            } else {
                backgroundSaveErrorPending = true
            }
            return false
        }
    }

    private var saveErrorAlert: FeatureAlert {
        FeatureAlert(
            title: "Couldn’t Save Progress",
            message: "Your changes are still in the visit. Try saving again."
        )
    }
}
