import Foundation
import Observation
import SwiftData

nonisolated enum InvoiceCreationLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class InvoiceCreationModel {
    let clientID: PersistentIdentifier
    var draft: InvoiceCreationDraft?
    private(set) var clientName: String?
    private(set) var visitChoices: [InvoiceVisitChoice] = []
    private(set) var hasValidBusinessProfile = false
    private(set) var loadState: InvoiceCreationLoadState = .loading
    private(set) var isGenerating = false
    var alert: FeatureAlert?

    var canGenerate: Bool {
        guard
            loadState == .loaded,
            hasValidBusinessProfile,
            !isGenerating,
            let draft,
            !draft.selectedVisitIDs.isEmpty
        else {
            return false
        }
        return draft.selectedVisitIDs.isSubset(of: Set(visitChoices.map(\.id)))
    }

    init(clientID: PersistentIdentifier) {
        self.clientID = clientID
    }

    func load(
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        loadState = .loading
        do {
            guard let client = try context.existingModel(Client.self, for: clientID) else {
                throw InvoiceGenerationError.clientUnavailable
            }
            let choices = try InvoiceEligibilityRules.choices(
                for: clientID,
                in: context
            )
            let profile = try currentBusinessProfile(in: context)
            clientName = client.name
            visitChoices = choices
            hasValidBusinessProfile = profile.map { isValid($0) } ?? false

            if var draft {
                draft.selectedVisitIDs.formIntersection(Set(choices.map(\.id)))
                self.draft = draft
            } else {
                self.draft = InvoiceCreationDraft(
                    clientID: clientID,
                    selectedVisitIDs: [],
                    invoiceDate: now,
                    dueDate: try InvoiceDateRules.defaultDueDate(
                        for: now,
                        calendar: calendar
                    ),
                    note: hasValidBusinessProfile
                        ? profile?.defaultInvoiceNote ?? ""
                        : ""
                )
            }
            alert = nil
            loadState = .loaded
        } catch {
            loadState = .failed
            clientName = nil
            visitChoices = []
            hasValidBusinessProfile = false
            alert = FeatureAlert(
                title: "Invoice Unavailable",
                message: "FarrierFlow couldn’t load this invoice. Try again."
            )
        }
    }

    func toggleVisit(_ visitID: PersistentIdentifier) {
        guard
            var draft,
            visitChoices.contains(where: { $0.id == visitID })
        else {
            return
        }
        if draft.selectedVisitIDs.contains(visitID) {
            draft.selectedVisitIDs.remove(visitID)
        } else {
            draft.selectedVisitIDs.insert(visitID)
        }
        self.draft = draft
    }

    func selectAll() {
        guard var draft else {
            return
        }
        draft.selectedVisitIDs = Set(visitChoices.map(\.id))
        self.draft = draft
    }

    @discardableResult
    func generate(in context: ModelContext) -> PersistentIdentifier? {
        guard let draft, canGenerate else {
            return nil
        }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let invoiceID = try InvoiceGenerationUseCase.generate(draft, in: context)
            alert = nil
            return invoiceID
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Generate Invoice",
                message: "Your visit selection is unchanged. Try again."
            )
            return nil
        }
    }

    private func currentBusinessProfile(
        in context: ModelContext
    ) throws -> BusinessProfile? {
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 2
        let profiles = try context.fetch(descriptor)
        return profiles.count == 1 ? profiles.first : nil
    }

    private func isValid(_ profile: BusinessProfile) -> Bool {
        guard profile.nextInvoiceNumber > 0 else {
            return false
        }
        guard let values = try? BusinessProfileRules.validated(
            BusinessProfileDraft(
                name: profile.name,
                phone: profile.phone ?? "",
                email: profile.email ?? "",
                address: profile.address ?? "",
                defaultInvoiceNote: profile.defaultInvoiceNote ?? ""
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
