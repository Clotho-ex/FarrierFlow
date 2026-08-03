import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class NextAppointmentAssistantModel {
    private struct HorseAvailability {
        let reason: NextAppointmentHorseUnavailabilityReason?
        let futureAppointment: Appointment?
    }

    private let visitID: PersistentIdentifier
    private var projectionCalendar: Calendar?

    private(set) var loadState: NextAppointmentAssistantLoadState = .loading
    private(set) var projection: NextAppointmentAssistantProjection?

    init(visitID: PersistentIdentifier) {
        self.visitID = visitID
    }

    func load(
        in context: ModelContext,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) {
        loadState = .loading
        projection = nil
        projectionCalendar = calendar

        do {
            let source = try SourceGraph.resolve(
                visitID: visitID,
                in: context
            )
            let options = try source.visitHorses.map { visitHorse in
                try makeOption(
                    for: visitHorse,
                    source: source,
                    in: context,
                    now: now,
                    calendar: calendar
                )
            }.sorted { lhs, rhs in
                let nameOrder = lhs.horseName.compare(
                    rhs.horseName,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: nil,
                    locale: locale
                )
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return lhs.id < rhs.id
            }

            let selectedSuggestions = options.compactMap { option in
                option.isSelected ? option.suggestedStart : nil
            }
            let groupSuggestion = NextAppointmentSuggestionRules.groupSuggestedStart(
                selectedSuggestedDates: selectedSuggestions
            )
            projection = NextAppointmentAssistantProjection(
                sourceVisitID: source.visit.persistentModelID,
                sourceBarnID: source.barn.persistentModelID,
                sourceBarnName: source.barn.name,
                sourceWorkDate: calendar.startOfDay(for: source.visit.startedAt),
                projectionNow: now,
                options: options,
                proposedStart: NextAppointmentSuggestionRules.editorStart(
                    groupSuggestion: groupSuggestion,
                    now: now,
                    calendar: calendar
                ),
                hasFollowUpSuggestion: groupSuggestion != nil,
                isManuallyOverridden: false
            )
            loadState = .loaded
        } catch let error as NextAppointmentAssistantLoadError {
            loadState = .failed(error)
            projectionCalendar = nil
        } catch {
            loadState = .failed(.projectionUnavailable)
            projectionCalendar = nil
        }
    }

    func toggleHorse(_ visitHorseID: PersistentIdentifier) {
        guard loadState == .loaded,
              var projection,
              let index = projection.options.firstIndex(where: { $0.id == visitHorseID }),
              projection.options[index].unavailabilityReason == nil
        else {
            return
        }

        projection.options[index].isSelected.toggle()
        if !projection.isManuallyOverridden {
            updateProposedStart(&projection)
        }
        self.projection = projection
    }

    func setProposedStart(_ date: Date) {
        guard loadState == .loaded, var projection else {
            return
        }
        projection.proposedStart = date
        projection.isManuallyOverridden = true
        self.projection = projection
    }

    func makeSeed() -> NextAppointmentSeed? {
        guard loadState == .loaded, let projection else {
            return nil
        }

        let selectedHorseIDs = Set(
            projection.options
                .filter(\.isSelected)
                .map(\.horseID)
        )
        guard !selectedHorseIDs.isEmpty else {
            return nil
        }

        return NextAppointmentSeed(
            barnID: projection.sourceBarnID,
            horseIDs: selectedHorseIDs,
            startDate: projection.proposedStart,
            hasFollowUpSuggestion: projection.options.contains {
                $0.isSelected && $0.suggestedStart != nil
            }
        )
    }

    private func updateProposedStart(_ projection: inout NextAppointmentAssistantProjection) {
        guard let projectionCalendar else {
            return
        }
        let groupSuggestion = NextAppointmentSuggestionRules.groupSuggestedStart(
            selectedSuggestedDates: projection.options.compactMap { option in
                option.isSelected ? option.suggestedStart : nil
            }
        )
        projection.proposedStart = NextAppointmentSuggestionRules.editorStart(
            groupSuggestion: groupSuggestion,
            now: projection.projectionNow,
            calendar: projectionCalendar
        )
        projection.hasFollowUpSuggestion = groupSuggestion != nil
    }

    private func makeOption(
        for visitHorse: VisitHorse,
        source: SourceGraph,
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws -> NextAppointmentHorseOption {
        guard
            visitHorse.visit === source.visit,
            let horse = visitHorse.horse
        else {
            throw NextAppointmentAssistantLoadError.sourceAppointmentUnavailable
        }

        let outcome = VisitOutcome(rawValue: visitHorse.outcomeRawValue)
        let availability: HorseAvailability
        do {
            availability = try resolveAvailability(
                for: horse,
                outcome: outcome,
                source: source,
                in: context,
                now: now
            )
        } catch {
            return NextAppointmentHorseOption(
                id: visitHorse.persistentModelID,
                horseID: horse.persistentModelID,
                horseName: horse.name,
                outcome: outcome ?? .pending,
                intervalWeeks: horse.appointmentIntervalWeeks > 0
                    ? horse.appointmentIntervalWeeks
                    : nil,
                suggestedStart: nil,
                isSelected: false,
                unavailabilityReason: .invalidCurrentGraph,
                scheduledAppointmentStart: nil,
                scheduledServiceLocationName: nil,
                currentServiceLocationName: horse.currentBarn?.name
            )
        }
        let isEligible = availability.reason == nil
        let suggestedStart: Date?
        if isEligible, outcome == .serviced {
            suggestedStart = NextAppointmentSuggestionRules.suggestedStart(
                visitStartedAt: source.visit.startedAt,
                intervalWeeks: horse.appointmentIntervalWeeks,
                sourceAppointmentStart: source.appointment.startDate,
                calendar: calendar
            )
        } else {
            suggestedStart = nil
        }

        let scheduledAppointment = availability.futureAppointment
        return NextAppointmentHorseOption(
            id: visitHorse.persistentModelID,
            horseID: horse.persistentModelID,
            horseName: horse.name,
            outcome: outcome ?? .pending,
            intervalWeeks: horse.appointmentIntervalWeeks > 0 ? horse.appointmentIntervalWeeks : nil,
            suggestedStart: suggestedStart,
            isSelected: isEligible && outcome == .serviced,
            unavailabilityReason: availability.reason,
            scheduledAppointmentStart: scheduledAppointment?.startDate,
            scheduledServiceLocationName: scheduledAppointment?.barn?.name,
            currentServiceLocationName: horse.currentBarn?.name
        )
    }

    private func resolveAvailability(
        for horse: Horse,
        outcome: VisitOutcome?,
        source: SourceGraph,
        in context: ModelContext,
        now: Date
    ) throws -> HorseAvailability {
        if let futureAppointment = try futureAppointment(
            for: horse,
            excluding: source.appointment,
            in: context,
            now: now
        ) {
            return HorseAvailability(
                reason: .alreadyScheduled,
                futureAppointment: futureAppointment
            )
        }
        if try hasNewerServicedVisit(for: horse, source: source, in: context) {
            return HorseAvailability(reason: .newerServicedVisit, futureAppointment: nil)
        }
        guard horse.currentBarn === source.barn else {
            return HorseAvailability(reason: .moved, futureAppointment: nil)
        }
        guard horse.client != nil else {
            return HorseAvailability(reason: .clientUnavailable, futureAppointment: nil)
        }
        guard horse.appointmentIntervalWeeks > 0 else {
            return HorseAvailability(reason: .invalidAppointmentInterval, futureAppointment: nil)
        }
        guard outcome == .serviced || outcome == .notServiced else {
            return HorseAvailability(reason: .invalidOutcome, futureAppointment: nil)
        }
        return HorseAvailability(reason: nil, futureAppointment: nil)
    }

    private func futureAppointment(
        for horse: Horse,
        excluding sourceAppointment: Appointment,
        in context: ModelContext,
        now: Date
    ) throws -> Appointment? {
        let memberships = try context.fetch(FetchDescriptor<AppointmentHorse>())
        let horseID = horse.persistentModelID
        let candidates = try memberships.compactMap { membership -> Appointment? in
            guard membership.horse?.persistentModelID == horseID else {
                return nil
            }
            guard let appointment = membership.appointment else {
                throw NextAppointmentAssistantLoadError.projectionUnavailable
            }
            guard membership.horse === horse,
                  appointment.appointmentHorses.contains(where: {
                      $0.persistentModelID == membership.persistentModelID
                  }),
                  appointment.barn != nil
            else {
                throw NextAppointmentAssistantLoadError.projectionUnavailable
            }
            guard appointment !== sourceAppointment, appointment.startDate >= now else {
                return nil
            }
            return appointment
        }
        return candidates.sorted {
            if $0.startDate != $1.startDate {
                return $0.startDate < $1.startDate
            }
            return $0.persistentModelID < $1.persistentModelID
        }.first
    }

    private func hasNewerServicedVisit(
        for horse: Horse,
        source: SourceGraph,
        in context: ModelContext
    ) throws -> Bool {
        let sourceRecency = CompletedVisitRecency(
            visitID: source.visit.persistentModelID,
            startedAt: source.visit.startedAt,
            completedAt: source.completedAt
        )!
        let memberships = try context.fetch(FetchDescriptor<VisitHorse>())
        for membership in memberships where membership.horse === horse {
            guard let candidate = membership.visit else {
                throw NextAppointmentAssistantLoadError.projectionUnavailable
            }
            guard candidate.persistentModelID != source.visit.persistentModelID else {
                continue
            }
            guard membership.visit === candidate,
                  candidate.visitHorses.contains(where: {
                      $0.persistentModelID == membership.persistentModelID
                  }),
                  candidate.appointment?.visit === candidate,
                  candidate.barn === candidate.appointment?.barn,
                  membership.horse === horse
            else {
                throw NextAppointmentAssistantLoadError.projectionUnavailable
            }
            guard membership.outcomeRawValue == VisitOutcome.serviced.rawValue else {
                continue
            }
            guard let completedAt = candidate.completedAt,
                  let candidateRecency = CompletedVisitRecency(
                      visitID: candidate.persistentModelID,
                      startedAt: candidate.startedAt,
                      completedAt: completedAt
                  )
            else {
                throw NextAppointmentAssistantLoadError.projectionUnavailable
            }
            if CompletedVisitRecency.precedes(
                candidateRecency,
                sourceRecency,
                sourceVisitID: source.visit.persistentModelID
            ) {
                return true
            }
        }
        return false
    }
}

@MainActor
private struct SourceGraph {
    let visit: Visit
    let appointment: Appointment
    let barn: Barn
    let completedAt: Date
    let visitHorses: [VisitHorse]

    static func resolve(
        visitID: PersistentIdentifier,
        in context: ModelContext
    ) throws -> SourceGraph {
        guard let visit = try context.existingModel(Visit.self, for: visitID),
              let completedAt = visit.completedAt,
              completedAt >= visit.startedAt,
              let appointment = visit.appointment,
              appointment.visit === visit,
              let appointmentBarn = appointment.barn,
              let visitBarn = visit.barn,
              visitBarn === appointmentBarn,
              TextNormalization.required(appointmentBarn.name) == appointmentBarn.name
        else {
            throw NextAppointmentAssistantLoadError.sourceAppointmentUnavailable
        }

        let persistedAppointmentHorses = try context.fetch(FetchDescriptor<AppointmentHorse>())
            .filter { $0.appointment === appointment }
        let persistedVisitHorses = try context.fetch(FetchDescriptor<VisitHorse>())
            .filter { $0.visit === visit }
        let appointmentHorseIDs = try validHorseIDs(
            persistedAppointmentHorses,
            belongingTo: appointment
        )
        let visitHorseIDs = try validHorseIDs(persistedVisitHorses, belongingTo: visit)
        guard appointmentHorseIDs == visitHorseIDs,
              Set(appointment.appointmentHorses.map(\.persistentModelID))
                  == Set(persistedAppointmentHorses.map(\.persistentModelID)),
              appointment.appointmentHorses.count == persistedAppointmentHorses.count,
              Set(visit.visitHorses.map(\.persistentModelID))
                  == Set(persistedVisitHorses.map(\.persistentModelID)),
              visit.visitHorses.count == persistedVisitHorses.count
        else {
            throw NextAppointmentAssistantLoadError.sourceAppointmentUnavailable
        }

        return SourceGraph(
            visit: visit,
            appointment: appointment,
            barn: appointmentBarn,
            completedAt: completedAt,
            visitHorses: persistedVisitHorses
        )
    }

    private static func validHorseIDs(
        _ memberships: [AppointmentHorse],
        belongingTo appointment: Appointment
    ) throws -> Set<PersistentIdentifier> {
        var horseIDs = Set<PersistentIdentifier>()
        for membership in memberships {
            guard membership.appointment === appointment,
                  let horse = membership.horse,
                  horseIDs.insert(horse.persistentModelID).inserted
            else {
                throw NextAppointmentAssistantLoadError.sourceAppointmentUnavailable
            }
        }
        return horseIDs
    }

    private static func validHorseIDs(
        _ memberships: [VisitHorse],
        belongingTo visit: Visit
    ) throws -> Set<PersistentIdentifier> {
        var horseIDs = Set<PersistentIdentifier>()
        for membership in memberships {
            guard membership.visit === visit,
                  let horse = membership.horse,
                  horseIDs.insert(horse.persistentModelID).inserted
            else {
                throw NextAppointmentAssistantLoadError.sourceAppointmentUnavailable
            }
        }
        return horseIDs
    }
}
