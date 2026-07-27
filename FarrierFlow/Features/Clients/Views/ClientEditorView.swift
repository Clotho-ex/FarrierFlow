import SwiftData
import SwiftUI

struct ClientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: ClientEditorModel

    init(client: Client? = nil) {
        _model = State(initialValue: ClientEditorModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    TextField("Name", text: $model.draft.name)
                        .textContentType(.name)
                        .accessibilityIdentifier("client-name-field")
                    TextField("Phone", text: $model.draft.phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $model.draft.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Client Notes") {
                    TextEditor(text: $model.draft.notes)
                        .accessibilityLabel("Client Notes")
                }
            }
            .navigationTitle(model.clientID == nil ? "New Client" : "Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save(in: context) != nil {
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }
}
