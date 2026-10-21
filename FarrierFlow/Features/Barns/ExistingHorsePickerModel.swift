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
    @ObservationIgnored
    private let saving: (ModelContext) throws -> Void

    private(set) var horses: [HorseDetailSnapshot] = []
    private(set) var loadState = ExistingHorsePickerLoadState.loading
    var selectedHorseID: PersistentIdentifier?
    var alert: FeatureAlert?
    private(set) var pendingRelocation: HorseRelocationConfirmation?

    init(
        horseFetcher: @escaping (ModelContext) throws -> [Horse] = {
            try $0.fetch(
                FetchDescriptor<Horse>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        },
        saving: @escaping (ModelContext) throws -> Void = {
            try DomainGraphValidator.save($0)
        }
    ) {
        self.horseFetcher = horseFetcher
        self.saving = saving
    }

    func load(destinationBarnID: PersistentIdentifier, in context: ModelContext) {
        loadState = .loading
        do {
            horses = try horseFetcher(context).filter { horse in
                guard horse.client != nil, horse.currentBarn != nil,
                      let projection = HorseRelocationRules.projection(
                          for: horse,
                          destinationBarnID: destinationBarnID
                      )
                else {
                    return false
                }
                return !projection.isSameBarn && HorseRelocationRules.canRelocate(
                    appointmentStates: projection.appointmentStates,
                    hasInProgressVisitHorse: projection.hasInProgressVisitHorse,
                    isSameBarn: projection.isSameBarn
                )
            }.map(HorseDetailSnapshot.init)
            loadState = .loaded
        } catch {
            loadState = .failed
            Self.logger.error(
                "Failed to load relocatable horses: \(error, privacy: .public)"
            )
        }
    }

    func move(
        to destinationBarnID: PersistentIdentifier,
        in context: ModelContext,
        confirming relocation: HorseRelocationConfirmation? = nil
    ) -> Bool {
        pendingRelocation = nil
        do {
            guard let selectedHorseID,
                  let horse = try context.existingModel(Horse.self, for: selectedHorseID),
                  let destination = try context.existingModel(Barn.self, for: destinationBarnID) else {
                alert = FeatureAlert(
                    title: "Can’t Move Horse",
                    message: "The horse or service location is no longer available. Choose another before moving."
                )
                return false
            }
            guard let originalBarn = horse.currentBarn,
                  let projection = HorseRelocationRules.projection(
                    for: horse,
                    destinationBarnID: destinationBarnID
                  ),
                  HorseRelocationRules.canRelocate(
                    appointmentStates: projection.appointmentStates,
                    hasInProgressVisitHorse: projection.hasInProgressVisitHorse,
                    isSameBarn: projection.isSameBarn
                  ) else {
                alert = FeatureAlert(
                    title: "Can’t Move Horse",
                    message: "Complete or remove unresolved appointments before moving this horse."
                )
                return false
            }
            if let move = HorseRelocationConfirmation(horse: horse, destination: destination),
               relocation != move {
                pendingRelocation = move
                alert = move.alert
                return false
            }
            horse.currentBarn = destination
            if !destination.horses.contains(where: { $0 === horse }) {
                destination.horses.append(horse)
            }

            do {
                try saving(context)
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
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Move Horse",
                message: "The horse remains at its previous service location."
            )
            return false
        }
    }
}
