import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientEditorModel {
    var draft: ClientDraft
    let clientID: PersistentIdentifier?
    var alert: FeatureAlert?

    var canSave: Bool { draft.isValid }

    init(client: Client? = nil) {
        clientID = client?.persistentModelID
        draft = ClientDraft(
            name: client?.name ?? "",
            phone: client?.phone ?? "",
            email: client?.email ?? "",
            notes: client?.notes ?? ""
        )
    }

    func save(in context: ModelContext) -> PersistentIdentifier? {
        guard let name = TextNormalization.required(draft.name) else { return nil }

        let client: Client
        if let clientID {
            guard let existing = context.model(for: clientID) as? Client else {
                alert = FeatureAlert(
                    title: "Client Unavailable",
                    message: "This client is no longer available."
                )
                return nil
            }
            client = existing
        } else {
            client = Client(name: name)
            context.insert(client)
        }

        client.name = name
        client.phone = TextNormalization.optional(draft.phone)
        client.email = TextNormalization.optional(draft.email)
        client.notes = TextNormalization.optional(draft.notes)

        do {
            try DomainGraphValidator.save(context)
            return client.persistentModelID
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Save Client",
                message: "Your changes are still in the form. Try saving again."
            )
            return nil
        }
    }
}
