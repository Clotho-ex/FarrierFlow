import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ExistingHorsePickerModel {
    private(set) var horses: [Horse] = []
    var selectedHorseID: PersistentIdentifier?
    var alert: FeatureAlert?

    func load(destinationBarnID: PersistentIdentifier, in context: ModelContext) {
        let descriptor = FetchDescriptor<Horse>(
            sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
        )
        horses = (try? context.fetch(descriptor))?.filter {
            $0.currentBarn?.persistentModelID != destinationBarnID
                && $0.appointmentHorses.isEmpty
                && $0.client != nil
                && $0.currentBarn != nil
        } ?? []
    }

    func move(to destinationBarnID: PersistentIdentifier, in context: ModelContext) -> Bool {
        guard
            let selectedHorseID,
            let horse = context.model(for: selectedHorseID) as? Horse,
            let destination = context.model(for: destinationBarnID) as? Barn,
            let currentBarnID = horse.currentBarn?.persistentModelID,
            HorseRelocationRules.canRelocate(
                appointmentMembershipCount: horse.appointmentHorses.count,
                currentBarnID: currentBarnID,
                destinationBarnID: destinationBarnID
            )
        else {
            alert = FeatureAlert(
                title: "Can’t Move Horse",
                message: "A horse with scheduled appointments can’t change service locations."
            )
            return false
        }

        horse.currentBarn = destination
        destination.horses.append(horse)

        do {
            try DomainGraphValidator.save(context)
            return true
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Move Horse",
                message: "The horse remains at its previous service location."
            )
            return false
        }
    }
}
