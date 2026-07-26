import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BarnEditorModel {
    var draft: BarnDraft
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
    }

    func save(in context: ModelContext) -> PersistentIdentifier? {
        guard let name = TextNormalization.required(draft.name) else { return nil }

        let barn: Barn
        if let barnID {
            guard let existing = context.model(for: barnID) as? Barn else {
                alert = FeatureAlert(
                    title: "Service Location Unavailable",
                    message: "This service location is no longer available."
                )
                return nil
            }
            barn = existing
        } else {
            barn = Barn(name: name)
            context.insert(barn)
        }

        barn.name = name
        barn.address = TextNormalization.optional(draft.address)
        barn.contactNotes = TextNormalization.optional(draft.contactNotes)

        do {
            try DomainGraphValidator.save(context)
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
