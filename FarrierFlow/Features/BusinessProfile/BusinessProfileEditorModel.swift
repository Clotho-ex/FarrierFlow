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
    var alert: FeatureAlert?

    var canSave: Bool {
        loadState == .loaded
            && (try? BusinessProfileRules.validated(draft)) != nil
    }

    func load(in context: ModelContext) {
        loadState = .loading
        do {
            let profiles = try fetchProfiles(in: context)
            guard profiles.count <= 1 else {
                loadState = .failed
                return
            }

            if let profile = profiles.first {
                draft = BusinessProfileDraft(
                    name: profile.name,
                    phone: profile.phone ?? "",
                    email: profile.email ?? "",
                    address: profile.address ?? "",
                    defaultInvoiceNote: profile.defaultInvoiceNote ?? "",
                    defaultAppointmentDurationMinutes: profile.defaultAppointmentDurationMinutes,
                    defaultInvoiceDueDays: profile.defaultInvoiceDueDays
                )
            } else {
                draft = BusinessProfileDraft()
            }
            alert = nil
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    func save(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator
    ) -> Bool {
        guard
            loadState == .loaded,
            let values = try? BusinessProfileRules.validated(draft)
        else {
            return false
        }

        return coordinator.withMutation {
            do {
                let profiles = try fetchProfiles(in: context)
                guard profiles.count <= 1 else {
                    throw BusinessProfileEditorError.multipleProfiles
                }

                let profile: BusinessProfile
                if let existing = profiles.first {
                    profile = existing
                } else {
                    profile = BusinessProfile(
                        name: values.name,
                        nextInvoiceNumber: 1
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

                try DomainGraphValidator.save(context)
                alert = nil
                return true
            } catch {
                context.rollback()
                alert = FeatureAlert(
                    title: "Couldn’t Save My Business",
                    message: "Your changes are still in the form. Try saving again."
                )
                return false
            }
        }
    }

    private func fetchProfiles(
        in context: ModelContext
    ) throws -> [BusinessProfile] {
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }
}

private enum BusinessProfileEditorError: Error {
    case multipleProfiles
}
