import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum AppointmentEditorLoadState: Equatable {
    case loading
    case loaded
    case failed
}

nonisolated enum AppointmentEditorLoadError: Error, Equatable {
    case appointmentUnavailable
    case invalidLockedGraph
}

nonisolated enum AppointmentStartDateRules {
    static func nextHalfHour(after now: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents(
            [.era, .year, .month, .day, .hour, .minute],
            from: now
        )
        guard let minuteStart = calendar.date(from: components) else {
            return now
        }
        let minute = calendar.component(.minute, from: minuteStart)
        let minutesToAdd = 30 - (minute % 30)
        return calendar.date(
            byAdding: .minute,
            value: minutesToAdd,
            to: minuteStart
        ) ?? now
    }
}

@MainActor
@Observable
final class AppointmentEditorModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "AppointmentEditor"
    )

    @ObservationIgnored
    private let barnFetcher: (ModelContext) throws -> [Barn]
    @ObservationIgnored
    private let horseFetcher: (ModelContext) throws -> [Horse]

    var draft: AppointmentDraft
    private(set) var barns: [Barn] = []
    private(set) var eligibleHorses: [Horse] = []
    private(set) var loadState = AppointmentEditorLoadState.loading
    private(set) var hasVisit = false
    private(set) var lockedBarnName: String?
    private(set) var lockedHorseNames: [String] = []
    private var lockedBarnID: PersistentIdentifier?
    private var lockedHorseIDs = Set<PersistentIdentifier>()
    private var hasAppliedOwnerDefault = false
    private(set) var appliedOwnerDurationDefault = false
    let appointmentID: PersistentIdentifier?
    let hasFollowUpSuggestion: Bool
    var alert: FeatureAlert?

    var canSave: Bool {
        loadState == .loaded && saveRequirement == nil
    }

    var saveRequirement: AppointmentSaveRequirement? {
        guard loadState == .loaded else { return nil }
        guard lockedDraftMatchesPersistedMembership else {
            return .lockedMembership
        }
        return draft.saveRequirement
    }

    init(
        appointment: Appointment? = nil,
        seed: NextAppointmentSeed? = nil,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        barnFetcher: @escaping (ModelContext) throws -> [Barn] = {
            try $0.fetch(
                FetchDescriptor<Barn>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        },
        horseFetcher: @escaping (ModelContext) throws -> [Horse] = {
            try $0.fetch(
                FetchDescriptor<Horse>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        }
    ) {
        self.barnFetcher = barnFetcher
        self.horseFetcher = horseFetcher
        let seed = appointment == nil ? seed : nil
        appointmentID = appointment?.persistentModelID
        hasFollowUpSuggestion = seed?.hasFollowUpSuggestion ?? false
        draft = AppointmentDraft(
            barnID: appointment?.barn?.persistentModelID ?? seed?.barnID,
            startDate: appointment?.startDate
                ?? seed?.startDate
                ?? AppointmentStartDateRules.nextHalfHour(
                    after: now,
                    calendar: calendar
                ),
            selectedHorseIDs: Set(
                appointment?.appointmentHorses.compactMap(\.horse?.persistentModelID) ?? []
            ).union(seed?.horseIDs ?? []),
            notes: appointment?.notes ?? "",
            expectedDurationText: appointment?.expectedDurationMinutes.map(String.init) ?? ""
        )
        updateVisitLock(from: appointment)
    }

    func load(in context: ModelContext) {
        loadState = .loading
        do {
            if let appointmentID {
                guard let appointment = try context.existingModel(
                    Appointment.self,
                    for: appointmentID
                ) else {
                    throw AppointmentEditorLoadError.appointmentUnavailable
                }
                if appointment.visit != nil {
                    let lock = try visitLock(for: appointment)
                    apply(lock, synchronizingDraft: true)
                    barns = []
                    eligibleHorses = []
                    loadState = .loaded
                    return
                }
                updateVisitLock(from: appointment)
            } else {
                try applyOwnerDefaultIfNeeded(in: context)
            }
            let loadedBarns = try barnFetcher(context)
            if
                let barnID = draft.barnID,
                !loadedBarns.contains(where: { $0.persistentModelID == barnID })
            {
                draft.barnID = nil
            }
            let loadedHorses = try eligibleHorses(
                at: draft.barnID,
                in: context
            )
            barns = loadedBarns
            eligibleHorses = loadedHorses
            retainEligibleSelections()
            loadState = .loaded
        } catch {
            loadState = .failed
            Self.logger.error(
                "Failed to load appointment editor choices: \(error, privacy: .public)"
            )
        }
    }

    func selectBarn(_ id: PersistentIdentifier?, in context: ModelContext) {
        guard !hasVisit else { return }
        draft.barnID = id
        loadEligibleHorses(in: context)
    }

    func selectCreatedBarn(_ id: PersistentIdentifier, in context: ModelContext) {
        guard !hasVisit else { return }
        loadState = .loading
        do {
            let loadedBarns = try barnFetcher(context)
            guard loadedBarns.contains(where: { $0.persistentModelID == id }) else {
                throw AppointmentEditorLoadError.appointmentUnavailable
            }
            barns = loadedBarns
            draft.barnID = id
            eligibleHorses = try eligibleHorses(at: id, in: context)
            retainEligibleSelections()
            loadState = .loaded
        } catch {
            loadState = .failed
            Self.logger.error(
                "Failed to select the created service location: \(error, privacy: .public)"
            )
        }
    }

    func selectCreatedHorse(_ id: PersistentIdentifier, in context: ModelContext) {
        guard !hasVisit, draft.barnID != nil else { return }
        loadEligibleHorses(in: context)
        guard
            loadState == .loaded,
            eligibleHorses.contains(where: { $0.persistentModelID == id })
        else {
            return
        }
        draft.selectedHorseIDs.insert(id)
    }

    func toggleHorse(_ id: PersistentIdentifier) {
        guard !hasVisit else { return }
        if draft.selectedHorseIDs.contains(id) {
            draft.selectedHorseIDs.remove(id)
        } else {
            draft.selectedHorseIDs.insert(id)
        }
    }

    func save(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) -> PersistentIdentifier? {
        guard
            draft.isValid,
            let barnID = draft.barnID,
            let barn = context.model(for: barnID) as? Barn
        else { return nil }

        return coordinator.withMutation {
            let existingAppointment: Appointment?
            if let appointmentID {
                guard let existing = context.model(for: appointmentID) as? Appointment else {
                    return nil
                }
                if existing.visit != nil {
                    let lock: AppointmentVisitLock
                    do {
                        lock = try visitLock(for: existing)
                        apply(lock, synchronizingDraft: false)
                    } catch {
                        alert = FeatureAlert(
                            title: "Appointment Unavailable",
                            message: "The appointment’s locked visit records couldn’t be verified."
                        )
                        return nil
                    }
                    guard lockedDraftMatchesPersistedMembership else {
                        alert = FeatureAlert(
                            title: "Work Has Started",
                            message: "The service location and horses can’t change after a visit starts."
                        )
                        return nil
                    }

                    existing.startDate = draft.startDate
                    existing.notes = TextNormalization.optional(draft.notes)
                    existing.expectedDurationMinutes = draft.expectedDurationMinutes
                    do {
                        try DomainGraphValidator.save(context)
                        return existing.persistentModelID
                    } catch {
                        context.rollback()
                        alert = FeatureAlert(
                            title: "Couldn’t Save Appointment",
                            message: "Your changes are still in the form. Try saving again."
                        )
                        return nil
                    }
                }
                existingAppointment = existing
            } else {
                existingAppointment = nil
            }

            let horses = draft.selectedHorseIDs.compactMap {
                context.model(for: $0) as? Horse
            }
            let eligibleIDs = Set(horses.filter {
                $0.currentBarn?.persistentModelID == barnID
                    && $0.client != nil
            }.map(\.persistentModelID))
            guard
                horses.count == draft.selectedHorseIDs.count,
                AppointmentRules.validate(
                    selectedHorseIDs: Array(draft.selectedHorseIDs),
                    eligibleHorseIDs: eligibleIDs
                ) == .valid
            else {
                alert = FeatureAlert(
                    title: "Review Selected Horses",
                    message: "Every selected horse must be at this service location."
                )
                return nil
            }

            let appointment: Appointment
            if let existingAppointment {
                appointment = existingAppointment
            } else {
                appointment = Appointment(startDate: draft.startDate, barn: barn)
                context.insert(appointment)
            }

            appointment.startDate = draft.startDate
            appointment.notes = TextNormalization.optional(draft.notes)
            appointment.expectedDurationMinutes = draft.expectedDurationMinutes
            appointment.barn = barn
            if !barn.appointments.contains(where: { $0 === appointment }) {
                barn.appointments.append(appointment)
            }

            let selectedIDs = draft.selectedHorseIDs
            for join in appointment.appointmentHorses
                where join.horse.map({
                    !selectedIDs.contains($0.persistentModelID)
                }) ?? true {
                context.delete(join)
            }

            let existingIDs = Set(
                appointment.appointmentHorses.compactMap(\.horse?.persistentModelID)
            )
            for horse in horses where !existingIDs.contains(horse.persistentModelID) {
                let join = AppointmentHorse(appointment: appointment, horse: horse)
                context.insert(join)
                appointment.appointmentHorses.append(join)
                horse.appointmentHorses.append(join)
            }

            do {
                try DomainGraphValidator.save(context)
                return appointment.persistentModelID
            } catch {
                context.rollback()
                alert = FeatureAlert(
                    title: "Couldn’t Save Appointment",
                    message: "Your changes are still in the form. Try saving again."
                )
                return nil
            }
        }
    }

    private func loadEligibleHorses(in context: ModelContext) {
        loadState = .loading
        do {
            eligibleHorses = try eligibleHorses(
                at: draft.barnID,
                in: context
            )
            retainEligibleSelections()
            loadState = .loaded
        } catch {
            loadState = .failed
            Self.logger.error(
                "Failed to load eligible appointment horses: \(error, privacy: .public)"
            )
        }
    }

    private func applyOwnerDefaultIfNeeded(in context: ModelContext) throws {
        guard !hasAppliedOwnerDefault else { return }
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 2
        let profiles = try context.fetch(descriptor)
        if
            profiles.count == 1,
            draft.expectedDurationText.isEmpty,
            let duration = profiles[0].defaultAppointmentDurationMinutes,
            duration > 0
        {
            draft.expectedDurationText = String(duration)
            appliedOwnerDurationDefault = true
        }
        hasAppliedOwnerDefault = true
    }

    private func eligibleHorses(
        at barnID: PersistentIdentifier?,
        in context: ModelContext
    ) throws -> [Horse] {
        guard let barnID else {
            return []
        }
        return try horseFetcher(context).filter {
            $0.currentBarn?.persistentModelID == barnID && $0.client != nil
        }
    }

    private func retainEligibleSelections() {
        guard !hasVisit else { return }
        guard draft.barnID != nil else {
            eligibleHorses = []
            draft.selectedHorseIDs = []
            return
        }
        let eligibleIDs = Set(eligibleHorses.map(\.persistentModelID))
        draft.selectedHorseIDs.formIntersection(eligibleIDs)
    }

    private var lockedDraftMatchesPersistedMembership: Bool {
        !hasVisit || (
            draft.barnID == lockedBarnID
                && draft.selectedHorseIDs == lockedHorseIDs
        )
    }

    private func updateVisitLock(from appointment: Appointment?) {
        guard let appointment, appointment.visit != nil else {
            hasVisit = false
            lockedBarnID = nil
            lockedBarnName = nil
            lockedHorseIDs = []
            lockedHorseNames = []
            return
        }

        hasVisit = true
        lockedBarnID = appointment.barn?.persistentModelID
        lockedBarnName = appointment.barn?.name
        lockedHorseIDs = Set(
            appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID }
        )
        lockedHorseNames = appointment.appointmentHorses
            .compactMap(\.horse?.name)
            .sorted(using: String.StandardComparator(.localizedStandard))
    }

    private func visitLock(for appointment: Appointment) throws -> AppointmentVisitLock {
        guard
            let barn = appointment.barn,
            let barnName = TextNormalization.required(barn.name),
            let visit = appointment.visit,
            visit.appointment === appointment,
            visit.barn === barn,
            TextNormalization.required(visit.serviceLocationNameSnapshot) != nil,
            !appointment.appointmentHorses.isEmpty,
            !visit.visitHorses.isEmpty
        else {
            throw AppointmentEditorLoadError.invalidLockedGraph
        }

        var appointmentHorseIDs = Set<PersistentIdentifier>()
        var horseNames: [String] = []
        for membership in appointment.appointmentHorses {
            guard
                membership.appointment === appointment,
                let horse = membership.horse,
                horse.client != nil,
                horse.currentBarn != nil,
                let horseName = TextNormalization.required(horse.name),
                appointmentHorseIDs.insert(horse.persistentModelID).inserted
            else {
                throw AppointmentEditorLoadError.invalidLockedGraph
            }
            horseNames.append(horseName)
        }

        var visitHorseIDs = Set<PersistentIdentifier>()
        var hasPendingHorse = false
        var hasServicedHorse = false
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
                throw AppointmentEditorLoadError.invalidLockedGraph
            }
            hasPendingHorse = hasPendingHorse || outcome == .pending
            hasServicedHorse = hasServicedHorse || outcome == .serviced
        }

        guard visitHorseIDs == appointmentHorseIDs else {
            throw AppointmentEditorLoadError.invalidLockedGraph
        }
        if let completedAt = visit.completedAt {
            guard
                completedAt >= visit.startedAt,
                !hasPendingHorse,
                hasServicedHorse
            else {
                throw AppointmentEditorLoadError.invalidLockedGraph
            }
        } else {
            guard visit.visitHorses.allSatisfy({
                $0.horse?.currentBarn === barn
            }) else {
                throw AppointmentEditorLoadError.invalidLockedGraph
            }
        }

        return AppointmentVisitLock(
            barnID: barn.persistentModelID,
            barnName: barnName,
            horseIDs: appointmentHorseIDs,
            horseNames: horseNames.sorted(
                using: String.StandardComparator(.localizedStandard)
            )
        )
    }

    private func apply(
        _ lock: AppointmentVisitLock,
        synchronizingDraft: Bool
    ) {
        hasVisit = true
        lockedBarnID = lock.barnID
        lockedBarnName = lock.barnName
        lockedHorseIDs = lock.horseIDs
        lockedHorseNames = lock.horseNames
        if synchronizingDraft {
            draft.barnID = lock.barnID
            draft.selectedHorseIDs = lock.horseIDs
        }
    }
}

private struct AppointmentVisitLock {
    let barnID: PersistentIdentifier
    let barnName: String
    let horseIDs: Set<PersistentIdentifier>
    let horseNames: [String]
}
