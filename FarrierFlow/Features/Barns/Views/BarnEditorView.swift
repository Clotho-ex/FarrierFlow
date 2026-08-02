import SwiftData
import SwiftUI

struct BarnEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: BarnEditorModel
    @State private var showsMoreDetails: Bool
    private let createdBarnID: Binding<PersistentIdentifier?>?

    init(
        barn: Barn? = nil,
        createdBarnID: Binding<PersistentIdentifier?>? = nil
    ) {
        _model = State(initialValue: BarnEditorModel(barn: barn))
        _showsMoreDetails = State(initialValue: barn != nil)
        self.createdBarnID = createdBarnID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Barn or Service Location") {
                    TextField("Name", text: $model.draft.name)
                        .accessibilityIdentifier("barn-name-field")
                    DisclosureGroup(
                        "Arrival Details",
                        isExpanded: $showsMoreDetails
                    ) {
                        TextField(
                            "Address",
                            text: $model.draft.address,
                            axis: .vertical
                        )
                        TextEditor(text: $model.draft.contactNotes)
                            .frame(minHeight: 88)
                            .accessibilityLabel("Contact Notes")
                        Text("Gate codes, parking, or arrival instructions.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("barn-more-details")
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
