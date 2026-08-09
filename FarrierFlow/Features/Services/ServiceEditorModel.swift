import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ServiceEditorModel {
    var draft: ServiceDraft
    let serviceID: PersistentIdentifier?
    var alert: FeatureAlert?

    var canSave: Bool {
        (try? ServiceRules.validated(draft)) != nil
    }

    init(service: Service? = nil) {
        serviceID = service?.persistentModelID
        draft = ServiceDraft(
            name: service?.name ?? "",
            priceInput: service.flatMap {
                USDPriceParser.editableString(minorUnits: $0.defaultAmountMinorUnits)
            } ?? ""
        )
    }

    func save(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) -> PersistentIdentifier? {
        let values: ServiceValues
        do {
            values = try ServiceRules.validated(draft)
        } catch {
            return nil
        }

        return coordinator.withMutation {
            let service: Service
            if let serviceID {
                guard let existing = context.model(for: serviceID) as? Service else {
                    alert = FeatureAlert(
                        title: "Service Unavailable",
                        message: "This service is no longer available."
                    )
                    return nil
                }
                service = existing
            } else {
                service = Service(
                    name: values.name,
                    defaultAmountMinorUnits: values.defaultAmountMinorUnits,
                    currencyCode: values.currencyCode
                )
                context.insert(service)
            }

            service.name = values.name
            service.defaultAmountMinorUnits = values.defaultAmountMinorUnits
            service.currencyCode = values.currencyCode

            do {
                try DomainGraphValidator.save(context)
                return service.persistentModelID
            } catch {
                context.rollback()
                alert = FeatureAlert(
                    title: "Couldn’t Save Service",
                    message: "Your changes are still in the form. Try saving again."
                )
                return nil
            }
        }
    }
}
