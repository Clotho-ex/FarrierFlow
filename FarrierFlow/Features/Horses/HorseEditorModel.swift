import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum HorseEditorChoicesLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class HorseEditorModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "HorseEditor"
    )

    @ObservationIgnored
    private let clientFetcher: (ModelContext) throws -> [Client]
    @ObservationIgnored
    private let barnFetcher: (ModelContext) throws -> [Barn]
    @ObservationIgnored
    private let serviceFetcher: (ModelContext) throws -> [Service]

    var draft: HorseDraft
    let horseID: PersistentIdentifier?
    private(set) var clients: [Client] = []
    private(set) var barns: [Barn] = []
    private(set) var activeServiceChoices: [ServiceChoice] = []
    private(set) var choicesLoadState = HorseEditorChoicesLoadState.loading
    var alert: FeatureAlert?

    var canSave: Bool {
        draft.isValid
            && choicesLoadState == .loaded
            && defaultServiceSelectionIsValid
    }

    init(
        horse: Horse? = nil,
        preselectedClientID: PersistentIdentifier? = nil,
        preselectedBarnID: PersistentIdentifier? = nil,
        clientFetcher: @escaping (ModelContext) throws -> [Client] = {
            try $0.fetch(
                FetchDescriptor<Client>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        },
        barnFetcher: @escaping (ModelContext) throws -> [Barn] = {
            try $0.fetch(
                FetchDescriptor<Barn>(
                    sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
                )
            )
        },
        serviceFetcher: @escaping (ModelContext) throws -> [Service] = {
            try $0.fetch(FetchDescriptor<Service>())
        }
    ) {
        self.clientFetcher = clientFetcher
        self.barnFetcher = barnFetcher
        self.serviceFetcher = serviceFetcher
        horseID = horse?.persistentModelID
        draft = HorseDraft(
            name: horse?.name ?? "",
            safetyNotes: horse?.safetyNotes ?? "",
            appointmentIntervalWeeks: horse?.appointmentIntervalWeeks ?? 6,
            clientID: horse?.client?.persistentModelID ?? preselectedClientID,
            barnID: horse?.currentBarn?.persistentModelID ?? preselectedBarnID,
            defaultServiceID: horse?.defaultService?.persistentModelID
        )
    }

    func loadChoices(in context: ModelContext) {
        choicesLoadState = .loading
        do {
            let loadedClients = try clientFetcher(context)
            let loadedBarns = try barnFetcher(context)
            let loadedServices = try serviceFetcher(context)
            clients = loadedClients
            barns = loadedBarns
            activeServiceChoices = ServiceRules.activeChoices(loadedServices)
            choicesLoadState = .loaded
        } catch {
            choicesLoadState = .failed
            Self.logger.error(
                "Failed to load horse editor choices: \(error, privacy: .public)"
            )
        }
    }

    func selectCreatedClient(
        _ id: PersistentIdentifier,
        in context: ModelContext
    ) {
        loadChoices(in: context)
        guard
            choicesLoadState == .loaded,
            clients.contains(where: { $0.persistentModelID == id })
        else {
            return
        }
        draft.clientID = id
    }

    func save(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) -> PersistentIdentifier? {
        guard
            let name = TextNormalization.required(draft.name),
            draft.appointmentIntervalWeeks > 0,
            let clientID = draft.clientID,
            let barnID = draft.barnID,
            let client = context.model(for: clientID) as? Client,
            let barn = context.model(for: barnID) as? Barn
        else { return nil }

        return coordinator.withMutation {
            let defaultService: Service?
            if let defaultServiceID = draft.defaultServiceID {
                guard
                    activeServiceChoices.contains(where: { $0.id == defaultServiceID }),
                    let service = context.model(for: defaultServiceID) as? Service,
                    ServiceRules.activeChoices([service]).count == 1
                else {
                    alert = FeatureAlert(
                        title: "Default Service Unavailable",
                        message: "Choose an active service or None before saving this horse."
                    )
                    return nil
                }
                defaultService = service
            } else {
                defaultService = nil
            }

            let horse: Horse
            if let horseID {
                guard let existing = context.model(for: horseID) as? Horse else {
                    return nil
                }
                guard existing.currentBarn != nil else {
                    alert = FeatureAlert(
                        title: "Horse Unavailable",
                        message: "This horse is missing its current service location."
                    )
                    return nil
                }
                guard
                    let projection = HorseRelocationRules.projection(
                        for: existing,
                        destinationBarnID: barnID
                    ),
                    HorseRelocationRules.canRelocate(
                        appointmentStates: projection.appointmentStates,
                        hasInProgressVisitHorse: projection.hasInProgressVisitHorse,
                        isSameBarn: projection.isSameBarn
                    )
                else {
                    alert = FeatureAlert(
                        title: "Can’t Change Service Location",
                        message: "Complete or remove unresolved appointments before changing this service location."
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
            horse.defaultService = defaultService
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

    private var defaultServiceSelectionIsValid: Bool {
        guard let defaultServiceID = draft.defaultServiceID else { return true }
        return activeServiceChoices.contains { $0.id == defaultServiceID }
    }

}
