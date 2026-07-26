import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppointmentEditorModel {
    var draft: AppointmentDraft
    private(set) var barns: [Barn] = []
    private(set) var eligibleHorses: [Horse] = []
    let appointmentID: PersistentIdentifier?
    var alert: FeatureAlert?

    var canSave: Bool { draft.isValid }

    init(appointment: Appointment? = nil) {
        appointmentID = appointment?.persistentModelID
        draft = AppointmentDraft(
            barnID: appointment?.barn?.persistentModelID,
            startDate: appointment?.startDate ?? .now,
            selectedHorseIDs: Set(
                appointment?.appointmentHorses.compactMap(\.horse?.persistentModelID) ?? []
            ),
            notes: appointment?.notes ?? "",
            expectedDurationText: appointment?.expectedDurationMinutes.map(String.init) ?? ""
        )
    }

    func load(in context: ModelContext) {
        barns = (try? context.fetch(
            FetchDescriptor<Barn>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
        )) ?? []
        loadEligibleHorses(in: context)
    }

    func selectBarn(_ id: PersistentIdentifier?, in context: ModelContext) {
        draft.barnID = id
        loadEligibleHorses(in: context)
        let eligibleIDs = Set(eligibleHorses.map(\.persistentModelID))
        draft.selectedHorseIDs.formIntersection(eligibleIDs)
    }

    func toggleHorse(_ id: PersistentIdentifier) {
        if draft.selectedHorseIDs.contains(id) {
            draft.selectedHorseIDs.remove(id)
        } else {
            draft.selectedHorseIDs.insert(id)
        }
    }

    func save(in context: ModelContext) -> PersistentIdentifier? {
        guard
            draft.isValid,
            let barnID = draft.barnID,
            let barn = context.model(for: barnID) as? Barn
        else { return nil }

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
        if let appointmentID {
            guard let existing = context.model(for: appointmentID) as? Appointment else {
                return nil
            }
            appointment = existing
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

    private func loadEligibleHorses(in context: ModelContext) {
        guard let barnID = draft.barnID else {
            eligibleHorses = []
            return
        }
        eligibleHorses = ((try? context.fetch(
            FetchDescriptor<Horse>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
        )) ?? []).filter {
            $0.currentBarn?.persistentModelID == barnID && $0.client != nil
        }
    }
}
