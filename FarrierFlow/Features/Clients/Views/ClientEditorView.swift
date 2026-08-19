import SwiftData
import SwiftUI

struct ClientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: ClientEditorModel
    @State private var showsMoreDetails: Bool
    private let createdClientID: Binding<PersistentIdentifier?>?

    init(
        client: Client? = nil,
        createdClientID: Binding<PersistentIdentifier?>? = nil
    ) {
        _model = State(initialValue: ClientEditorModel(client: client))
        _showsMoreDetails = State(initialValue: client != nil)
        self.createdClientID = createdClientID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    TextField("Name", text: $model.draft.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("client-name-field")
                    DisclosureGroup(
                        "More Details",
                        isExpanded: $showsMoreDetails
                    ) {
                        TextField("Phone", text: $model.draft.phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $model.draft.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextEditor(text: $model.draft.notes)
                            .frame(minHeight: 88)
                            .accessibilityLabel("Client Notes")
                    }
                    .accessibilityIdentifier("client-more-details")
                }
            }
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.clientID == nil ? "New Client" : "Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscription.allowsMutations else { return }
                        if let id = model.save(in: context) {
                            createdClientID?.wrappedValue = id
                            dismiss()
                        }
                    }
                    .disabled(!subscription.allowsMutations || !model.canSave)
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }
}
