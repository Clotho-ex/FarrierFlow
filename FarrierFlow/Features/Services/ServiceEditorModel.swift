import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ServiceEditorModel {
    @ObservationIgnored private let locale: Locale
    var draft: ServiceDraft
    @ObservationIgnored private var originalDraft: ServiceDraft?
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
        originalDraft = service == nil ? nil : draft
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

    func save(
        in context: ModelContext,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) -> PersistentIdentifier? {
        if let originalDraft, let serviceID {
            do {
                if let current = try ModelContext(context.container).existingModel(Service.self, for: serviceID) {
                    draft = try DraftSaveRules.merge(original: originalDraft, proposed: draft,
                        current: ServiceEditorModel(service: current, locale: locale).draft)
                }
            } catch {
                alert = DraftSaveRules.changedAlert
                return nil
            }
        }
        let values: ServiceValues
        do {
            values = try ServiceRules.validated(draft, locale: locale)
        } catch {
            return nil
        }

        let isCreating = serviceID == nil
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
        do {
            let service: Service
            if let serviceID {
                guard let existing = try context.existingModel(Service.self, for: serviceID) else {
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

            try DomainGraphValidator.save(context)
            draft = ServiceEditorModel(service: service, locale: locale).draft
            originalDraft = draft
            if isCreating {
                analyticsClient.track(.serviceCreated)
            }
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
