import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum ExistingHorsePickerLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class ExistingHorsePickerModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "ExistingHorsePicker"
    )

    @ObservationIgnored
    private let horseFetcher: (ModelContext) throws -> [Horse]

    private(set) var horses: [Horse] = []
    private(set) var loadState = ExistingHorsePickerLoadState.loading
    var selectedHorseID: PersistentIdentifier?
    var alert: FeatureAlert?

    init(
        horseFetcher: @escaping (ModelContext) throws -> [Horse] = {
            try $0.fetch(
                FetchDescriptor<Horse>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        }
    ) {
        self.horseFetcher = horseFetcher
    }

    func load(destinationBarnID: PersistentIdentifier, in context: ModelContext) {
        loadState = .loading
        do {
            horses = try horseFetcher(context).filter {
                $0.currentBarn?.persistentModelID != destinationBarnID
                    && $0.appointmentHorses.isEmpty
                    && $0.client != nil
                    && $0.currentBarn != nil
            }
            loadState = .loaded
        } catch {
            loadState = .failed
            Self.logger.error(
                "Failed to load relocatable horses: \(error, privacy: .public)"
            )
        }
    }

    func move(to destinationBarnID: PersistentIdentifier, in context: ModelContext) -> Bool {
        guard
            let selectedHorseID,
            let horse = context.model(for: selectedHorseID) as? Horse,
            let destination = context.model(for: destinationBarnID) as? Barn,
            let originalBarn = horse.currentBarn,
            HorseRelocationRules.canRelocate(
                appointmentMembershipCount: horse.appointmentHorses.count,
                currentBarnID: originalBarn.persistentModelID,
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
        if !destination.horses.contains(where: { $0 === horse }) {
            destination.horses.append(horse)
        }

        do {
            try DomainGraphValidator.save(context)
            return true
        } catch {
            horse.currentBarn = originalBarn
            destination.horses.removeAll { $0 === horse }
            if !originalBarn.horses.contains(where: { $0 === horse }) {
                originalBarn.horses.append(horse)
            }
            alert = FeatureAlert(
                title: "Couldn’t Move Horse",
                message: "The horse remains at its previous service location."
            )
            return false
        }
    }
}
