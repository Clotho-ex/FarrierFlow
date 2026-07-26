import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HorseEditorModel {
    var draft: HorseDraft
    let horseID: PersistentIdentifier?
    private(set) var clients: [Client] = []
    private(set) var barns: [Barn] = []
    var alert: FeatureAlert?

    var canSave: Bool { draft.isValid }

    init(
        horse: Horse? = nil,
        preselectedClientID: PersistentIdentifier? = nil,
        preselectedBarnID: PersistentIdentifier? = nil
    ) {
        horseID = horse?.persistentModelID
        draft = HorseDraft(
            name: horse?.name ?? "",
            safetyNotes: horse?.safetyNotes ?? "",
            appointmentIntervalWeeks: horse?.appointmentIntervalWeeks ?? 6,
            clientID: horse?.client?.persistentModelID ?? preselectedClientID,
            barnID: horse?.currentBarn?.persistentModelID ?? preselectedBarnID
        )
    }

    func loadChoices(in context: ModelContext) {
        clients = (try? context.fetch(
            FetchDescriptor<Client>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
        )) ?? []
        barns = (try? context.fetch(
            FetchDescriptor<Barn>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
        )) ?? []
    }

    func save(in context: ModelContext) -> PersistentIdentifier? {
        guard
            let name = TextNormalization.required(draft.name),
            draft.appointmentIntervalWeeks > 0,
            let clientID = draft.clientID,
            let barnID = draft.barnID,
            let client = context.model(for: clientID) as? Client,
            let barn = context.model(for: barnID) as? Barn
        else { return nil }

        let horse: Horse
        if let horseID {
            guard let existing = context.model(for: horseID) as? Horse else {
                return nil
            }
            guard let currentBarnID = existing.currentBarn?.persistentModelID else {
                alert = FeatureAlert(
                    title: "Horse Unavailable",
                    message: "This horse is missing its current service location."
                )
                return nil
            }
            if currentBarnID != barnID
                && !HorseRelocationRules.canRelocate(
                    appointmentMembershipCount: existing.appointmentHorses.count,
                    currentBarnID: currentBarnID,
                    destinationBarnID: barnID
                ) {
                alert = FeatureAlert(
                    title: "Can’t Change Service Location",
                    message: "This horse is referenced by an appointment. Remove the appointment before changing its service location."
                )
                return nil
            }
            horse = existing
        } else {
            horse = Horse(name: name, client: client, currentBarn: barn)
            context.insert(horse)
        }

        horse.name = name
        horse.safetyNotes = TextNormalization.optional(draft.safetyNotes)
        horse.appointmentIntervalWeeks = draft.appointmentIntervalWeeks
        horse.client = client
        horse.currentBarn = barn
        if !client.horses.contains(where: { $0 === horse }) {
            client.horses.append(horse)
        }
        if !barn.horses.contains(where: { $0 === horse }) {
            barn.horses.append(horse)
        }

        do {
            try DomainGraphValidator.save(context)
            return horse.persistentModelID
        } catch {
            context.rollback()
            alert = FeatureAlert(
                title: "Couldn’t Save Horse",
                message: "Your changes are still in the form. Try saving again."
            )
            return nil
        }
    }
}
