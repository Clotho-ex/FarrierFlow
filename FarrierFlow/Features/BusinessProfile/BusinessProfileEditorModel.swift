import Foundation
import Observation
import SwiftData

nonisolated enum BusinessProfileEditorLoadState: Equatable {
    case loading
    case loaded
    case failed
}

struct BusinessSetupServiceDraft: Identifiable {
    let id = UUID()
    var service: ServiceDraft
}

@MainActor
@Observable
final class BusinessProfileEditorModel {
    var draft = BusinessProfileDraft()
    var setupServices: [BusinessSetupServiceDraft] = []
    @ObservationIgnored private var locale = Locale.current
    private(set) var loadState: BusinessProfileEditorLoadState = .loading
    private(set) var isCurrencyLocked = false
    var alert: FeatureAlert?

    @ObservationIgnored private var originalDraft: BusinessProfileDraft?
    @ObservationIgnored private var originalProfileID: PersistentIdentifier?

    private var originalCurrencyCode = "USD"

    var canSave: Bool {
        loadState == .loaded
            && (!isCurrencyLocked || draft.currencyCode == originalCurrencyCode)
            && (try? BusinessProfileRules.validated(draft)) != nil
            && setupServicesAreValid
    }

    func load(in context: ModelContext, locale: Locale = .current) {
        self.locale = locale
        loadState = .loading
        do {
            let profiles = try fetchProfiles(in: context)
            guard profiles.count <= 1 else {
                loadState = .failed
                return
            }

            isCurrencyLocked = try hasCurrencyBearingRecords(in: context)
            if let profile = profiles.first {
                originalCurrencyCode = profile.currencyCode
                draft = Self.snapshot(profile)
            } else {
                originalCurrencyCode = isCurrencyLocked
                    ? BusinessCurrency.unitedStatesDollar.rawValue
                    : BusinessCurrency.defaultCode(for: locale)
                draft = BusinessProfileDraft(currencyCode: originalCurrencyCode)
            }
            originalDraft = draft
            originalProfileID = profiles.first?.persistentModelID
            alert = nil
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    var setupServicesAreValid: Bool {
        setupServices.allSatisfy { (try? ServiceRules.validated(serviceDraft($0), locale: locale)) != nil }
    }

    var canOpenServiceCatalog: Bool {
        draft.currencyCode == originalCurrencyCode
    }

    func addSetupService() {
        setupServices.append(BusinessSetupServiceDraft(service: ServiceDraft(currencyCode: draft.currencyCode)))
    }

    func synchronizeServiceCurrency() {
        for index in setupServices.indices { setupServices[index].service.currencyCode = draft.currencyCode }
    }

    func refreshCurrencyLock(in context: ModelContext) {
        do {
            isCurrencyLocked = try hasCurrencyBearingRecords(in: context)
        } catch {
            alert = FeatureAlert(title: "Business Currency Unavailable", message: "Try reopening My Business before changing its currency.")
        }
    }

    private func serviceDraft(_ entry: BusinessSetupServiceDraft) -> ServiceDraft {
        var service = entry.service
        service.currencyCode = draft.currencyCode
        return service
    }

    func save(in context: ModelContext) -> Bool {
        guard
            loadState == .loaded,
            (try? BusinessProfileRules.validated(draft)) != nil
        else {
            return false
        }

        do {
            let profiles = try fetchProfiles(in: context)
            guard profiles.count <= 1 else {
                throw BusinessProfileEditorError.multipleProfiles
            }
            if let originalDraft {
                guard originalProfileID == profiles.first?.persistentModelID else { throw DraftSaveError.changedSinceEditing }
                if let profile = profiles.first {
                    draft = try DraftSaveRules.merge(original: originalDraft, proposed: draft, current: Self.snapshot(profile))
                }
            }
            let values = try BusinessProfileRules.validated(draft)
            let newServices = try setupServices.map { try ServiceRules.validated(serviceDraft($0), locale: locale) }
            let currencyIsLocked = try hasCurrencyBearingRecords(in: context)
            let persistedCurrencyCode = profiles.first?.currencyCode
                ?? BusinessCurrency.unitedStatesDollar.rawValue
            guard !currencyIsLocked || values.currencyCode == persistedCurrencyCode else {
                throw BusinessProfileEditorError.currencyLocked
            }

            let profile: BusinessProfile
            if let existing = profiles.first {
                profile = existing
            } else {
                profile = BusinessProfile(
                    name: values.name,
                    nextInvoiceNumber: 1,
                    currencyCode: values.currencyCode
                )
                context.insert(profile)
            }

            profile.name = values.name
            profile.phone = values.phone
            profile.email = values.email
            profile.address = values.address
            profile.defaultInvoiceNote = values.defaultInvoiceNote
            profile.defaultAppointmentDurationMinutes = values.defaultAppointmentDurationMinutes
            profile.defaultInvoiceDueDays = values.defaultInvoiceDueDays
            profile.currencyCode = values.currencyCode

            for service in newServices {
                context.insert(Service(
                    name: service.name, defaultAmountMinorUnits: service.defaultAmountMinorUnits,
                    currencyCode: service.currencyCode
                ))
            }
            try DomainGraphValidator.save(context)
            setupServices = []
            draft = Self.snapshot(profile)
            originalDraft = draft
            originalProfileID = profile.persistentModelID
            originalCurrencyCode = values.currencyCode
            isCurrencyLocked = currencyIsLocked || !newServices.isEmpty
            alert = nil
            return true
        } catch DraftSaveError.changedSinceEditing {
            alert = DraftSaveRules.changedAlert
            return false
        } catch BusinessProfileEditorError.currencyLocked {
            context.rollback()
            alert = FeatureAlert(
                title: "Currency Can’t Be Changed",
                message: "Your business currency is locked after services or financial records exist."
            )
            return false
        } catch {
            context.rollback()
            alert = FeatureAlert(
                title: "Couldn’t Save My Business",
                message: "Your changes are still in the form. Try saving again."
            )
            return false
        }
    }

    private static func snapshot(_ profile: BusinessProfile) -> BusinessProfileDraft {
        BusinessProfileDraft(
            name: profile.name,
            phone: profile.phone ?? "",
            email: profile.email ?? "",
            address: profile.address ?? "",
            defaultInvoiceNote: profile.defaultInvoiceNote ?? "",
            defaultAppointmentDurationMinutes: profile.defaultAppointmentDurationMinutes,
            defaultInvoiceDueDays: profile.defaultInvoiceDueDays,
            currencyCode: profile.currencyCode
        )
    }

    private func fetchProfiles(
        in context: ModelContext
    ) throws -> [BusinessProfile] {
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }

    private func hasCurrencyBearingRecords(in context: ModelContext) throws -> Bool {
        try context.fetchCount(FetchDescriptor<Service>()) > 0
            || context.fetchCount(FetchDescriptor<WorkItem>()) > 0
            || context.fetchCount(FetchDescriptor<Invoice>()) > 0
            || context.fetchCount(FetchDescriptor<InvoiceLineItem>()) > 0
            || context.fetchCount(FetchDescriptor<Payment>()) > 0
    }
}

private enum BusinessProfileEditorError: Error {
    case multipleProfiles
    case currencyLocked
}
