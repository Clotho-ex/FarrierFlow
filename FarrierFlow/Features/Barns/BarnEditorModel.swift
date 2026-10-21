import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BarnEditorModel {
    var draft: BarnDraft
    @ObservationIgnored private var originalDraft = BarnDraft()
    let barnID: PersistentIdentifier?
    var alert: FeatureAlert?

    var canSave: Bool { draft.isValid }

    init(barn: Barn? = nil) {
        barnID = barn?.persistentModelID
        draft = BarnDraft(
            name: barn?.name ?? "",
            address: barn?.address ?? "",
            contactNotes: barn?.contactNotes ?? ""
        )
        originalDraft = draft
    }

    func save(
        in context: ModelContext,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) -> PersistentIdentifier? {
        guard let name = TextNormalization.required(draft.name) else { return nil }

        let isCreating = barnID == nil
        do {
            let barn: Barn
            if let barnID {
                guard let existing = try context.existingModel(Barn.self, for: barnID) else {
                    alert = FeatureAlert(
                        title: "Service Location Unavailable",
                        message: "This service location is no longer available."
                    )
                    return nil
                }
                let current = BarnEditorModel(barn: existing).draft
                let proposed = BarnDraft(name: name, address: TextNormalization.optional(draft.address) ?? "", contactNotes: TextNormalization.optional(draft.contactNotes) ?? "")
                guard let merged = try? DraftSaveRules.mergeFields(original: originalDraft, proposed: proposed,
                    current: current, fields: [\.name, \.address, \.contactNotes]) else {
                    alert = DraftSaveRules.changedAlert
                    return nil
                }
                draft = merged
                barn = existing
            } else {
                barn = Barn(name: name)
                context.insert(barn)
            }

            barn.name = TextNormalization.required(draft.name) ?? name
            barn.address = TextNormalization.optional(draft.address)
            barn.contactNotes = TextNormalization.optional(draft.contactNotes)

            try DomainGraphValidator.save(context)
            draft = BarnEditorModel(barn: barn).draft
            originalDraft = draft
            if isCreating {
                analyticsClient.track(.serviceLocationCreated)
            }
            return barn.persistentModelID
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Save Service Location",
                message: "Your changes are still in the form. Try saving again."
            )
            return nil
        }
    }
}
