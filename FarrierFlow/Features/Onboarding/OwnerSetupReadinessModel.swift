import Foundation
import Observation
import SwiftData

nonisolated enum OwnerSetupLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class OwnerSetupReadinessModel {
    private(set) var loadState: OwnerSetupLoadState = .loading
    private(set) var hasValidIdentity = false

    func load(in context: ModelContext) {
        loadState = .loading
        do {
            var profileDescriptor = FetchDescriptor<BusinessProfile>()
            profileDescriptor.fetchLimit = 2
            let profiles = try context.fetch(profileDescriptor)
            let profile = profiles.count == 1 ? profiles.first : nil
            hasValidIdentity = profile.map(Self.isValidIdentity) ?? false
            loadState = .loaded
        } catch {
            hasValidIdentity = false
            loadState = .failed
        }
    }

    private static func isValidIdentity(_ profile: BusinessProfile) -> Bool {
        guard profile.nextInvoiceNumber > 0 else { return false }
        guard let values = try? BusinessProfileRules.validated(
            BusinessProfileDraft(
                name: profile.name,
                phone: profile.phone ?? "",
                email: profile.email ?? "",
                address: profile.address ?? "",
                defaultInvoiceNote: profile.defaultInvoiceNote ?? "",
                defaultAppointmentDurationMinutes: profile.defaultAppointmentDurationMinutes,
                defaultInvoiceDueDays: profile.defaultInvoiceDueDays
            )
        ) else {
            return false
        }
        return values.name == profile.name
            && values.phone == profile.phone
            && values.email == profile.email
            && values.address == profile.address
            && values.defaultInvoiceNote == profile.defaultInvoiceNote
    }
}
