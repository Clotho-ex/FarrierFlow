import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ServiceEditorModel {
    @ObservationIgnored private let locale: Locale
    var draft: ServiceDraft
    let serviceID: PersistentIdentifier?
    var alert: FeatureAlert?
    private(set) var hasLoadedBusinessCurrency = false

    var canSave: Bool {
        hasLoadedBusinessCurrency
            && (try? ServiceRules.validated(draft, locale: locale)) != nil
    }

    init(service: Service? = nil, locale: Locale = .current) {
        self.locale = locale
        serviceID = service?.persistentModelID
        draft = ServiceDraft(
            name: service?.name ?? "",
            priceInput: service.flatMap {
                MoneyInputParser.editableString(
                    minorUnits: $0.defaultAmountMinorUnits,
                    locale: locale
                )
            } ?? "",
            currencyCode: service?.currencyCode ?? "USD"
        )
    }

    func loadBusinessCurrency(in context: ModelContext) {
        do {
            var descriptor = FetchDescriptor<BusinessProfile>()
            descriptor.fetchLimit = 2
            let profiles = try context.fetch(descriptor)
            guard profiles.count == 1, let profile = profiles.first else {
                throw ServiceEditorError.businessProfileUnavailable
            }
            if serviceID == nil {
                draft.currencyCode = profile.currencyCode
            }
            guard draft.currencyCode == profile.currencyCode else {
                throw ServiceEditorError.businessProfileUnavailable
            }
            hasLoadedBusinessCurrency = true
            alert = nil
        } catch {
            hasLoadedBusinessCurrency = false
            alert = FeatureAlert(
                title: "Business Currency Unavailable",
                message: "Finish business setup before adding services."
            )
        }
    }

    func save(in context: ModelContext) -> PersistentIdentifier? {
        let values: ServiceValues
        do {
            values = try ServiceRules.validated(draft, locale: locale)
        } catch {
            return nil
        }

        do {
            var descriptor = FetchDescriptor<BusinessProfile>()
            descriptor.fetchLimit = 2
            let profiles = try context.fetch(descriptor)
            guard profiles.count == 1,
                  let profile = profiles.first,
                  profile.currencyCode == values.currencyCode
            else {
                throw ServiceEditorError.businessProfileUnavailable
            }
        } catch {
            alert = FeatureAlert(
                title: "Business Currency Unavailable",
                message: "Finish business setup before adding services."
            )
            return nil
        }

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

private enum ServiceEditorError: Error {
    case businessProfileUnavailable
}
