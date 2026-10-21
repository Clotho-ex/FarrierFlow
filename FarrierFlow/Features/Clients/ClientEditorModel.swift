import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClientEditorModel {
    var draft: ClientDraft
    @ObservationIgnored private var originalDraft = ClientDraft()
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
        originalDraft = draft
    }

    func save(
        in context: ModelContext,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) -> PersistentIdentifier? {
        guard let name = TextNormalization.required(draft.name) else { return nil }

        let isCreating = clientID == nil
        do {
            let client: Client
            if let clientID {
                guard let existing = try context.existingModel(Client.self, for: clientID) else {
                    alert = FeatureAlert(
                        title: "Client Unavailable",
                        message: "This client is no longer available."
                    )
                    return nil
                }
                let current = ClientEditorModel(client: existing).draft
                let proposed = ClientDraft(name: name, phone: TextNormalization.optional(draft.phone) ?? "", email: TextNormalization.optional(draft.email) ?? "", notes: TextNormalization.optional(draft.notes) ?? "")
                guard let merged = try? DraftSaveRules.mergeFields(original: originalDraft, proposed: proposed,
                    current: current, fields: [\.name, \.phone, \.email, \.notes]) else {
                    alert = DraftSaveRules.changedAlert
                    return nil
                }
                draft = merged
                client = existing
            } else {
                client = Client(name: name)
                context.insert(client)
            }

            client.name = TextNormalization.required(draft.name) ?? name
            client.phone = TextNormalization.optional(draft.phone)
            client.email = TextNormalization.optional(draft.email)
            client.notes = TextNormalization.optional(draft.notes)

            try DomainGraphValidator.save(context)
            draft = ClientEditorModel(client: client).draft
            originalDraft = draft
            if isCreating {
                analyticsClient.track(.clientCreated)
            }
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
