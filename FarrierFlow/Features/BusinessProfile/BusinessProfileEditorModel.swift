import Foundation
import Observation
import SwiftData

nonisolated enum BusinessProfileEditorLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class BusinessProfileEditorModel {
    var draft = BusinessProfileDraft()
    private(set) var loadState: BusinessProfileEditorLoadState = .loading
    private(set) var isCurrencyLocked = false
    var alert: FeatureAlert?

    private var originalCurrencyCode = "USD"

    var canSave: Bool {
        loadState == .loaded
            && (!isCurrencyLocked || draft.currencyCode == originalCurrencyCode)
            && (try? BusinessProfileRules.validated(draft)) != nil
    }

    func load(in context: ModelContext, locale: Locale = .current) {
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
                draft = BusinessProfileDraft(
                    name: profile.name,
                    phone: profile.phone ?? "",
                    email: profile.email ?? "",
                    address: profile.address ?? "",
                    defaultInvoiceNote: profile.defaultInvoiceNote ?? "",
                    defaultAppointmentDurationMinutes: profile.defaultAppointmentDurationMinutes,
                    defaultInvoiceDueDays: profile.defaultInvoiceDueDays,
                    currencyCode: profile.currencyCode
                )
            } else {
                originalCurrencyCode = isCurrencyLocked
                    ? BusinessCurrency.unitedStatesDollar.rawValue
                    : BusinessCurrency.defaultCode(for: locale)
                draft = BusinessProfileDraft(currencyCode: originalCurrencyCode)
            }
            alert = nil
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    func save(in context: ModelContext) -> Bool {
        guard
            loadState == .loaded,
            let values = try? BusinessProfileRules.validated(draft)
        else {
            return false
        }

        do {
            let profiles = try fetchProfiles(in: context)
            guard profiles.count <= 1 else {
                throw BusinessProfileEditorError.multipleProfiles
            }
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

            try DomainGraphValidator.save(context)
            originalCurrencyCode = values.currencyCode
            isCurrencyLocked = currencyIsLocked
            alert = nil
            return true
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
