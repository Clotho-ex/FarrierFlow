import SwiftData
import SwiftUI

struct BarnEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: BarnEditorModel
    private let createdBarnID: Binding<PersistentIdentifier?>?

    init(
        barn: Barn? = nil,
        createdBarnID: Binding<PersistentIdentifier?>? = nil
    ) {
        _model = State(initialValue: BarnEditorModel(barn: barn))
        self.createdBarnID = createdBarnID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Location") {
                    TextField("Name", text: $model.draft.name)
                        .accessibilityIdentifier("barn-name-field")
                    TextField("Address", text: $model.draft.address, axis: .vertical)
                }
                Section("Contact Notes") {
                    TextEditor(text: $model.draft.contactNotes)
                }
            }
            .navigationTitle(model.barnID == nil ? "New Service Location" : "Edit Service Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let id = model.save(in: context) {
                            createdBarnID?.wrappedValue = id
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
