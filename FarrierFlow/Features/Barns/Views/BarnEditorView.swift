import SwiftData
import SwiftUI

struct BarnEditorView: View {
    private enum Field: Hashable { case name, address, contactNotes }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: BarnEditorModel
    @State private var showsMoreDetails: Bool
    @State private var dismissalBaseline: BarnDraft?
    @FocusState private var focusedField: Field?
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
                RecordSection(Text("Barn or Service Location")) {
                    TextField("Name", text: $model.draft.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .accessibilityIdentifier("barn-name-field")
                        .inputLimit($model.draft.name, maximum: InputLimits.name)
                        .focusedInputAnchor(Field.name)
                    DisclosureGroup(isExpanded: $showsMoreDetails) {
                        TextField(
                            "Address",
                            text: $model.draft.address,
                            axis: .vertical
                        )
                        .focused($focusedField, equals: .address)
                        .textContentType(.fullStreetAddress)
                        .accessibilityIdentifier("barn-address-field")
                        .inputLimit($model.draft.address, maximum: InputLimits.address)
                        .focusedInputAnchor(Field.address)
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text("Contact Notes")
                                .font(.caption)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .accessibilityHidden(true)
                            TextEditor(text: $model.draft.contactNotes)
                                .frame(minHeight: 88)
                                .focused($focusedField, equals: .contactNotes)
                                .accessibilityLabel("Contact Notes")
                                .accessibilityIdentifier("barn-contact-notes-field")
                                .inputLimit($model.draft.contactNotes, maximum: InputLimits.notes)
                        }
                        .focusedInputAnchor(Field.contactNotes)
                        Text("Gate codes, parking, or arrival instructions.")
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                    } label: {
                        Text("Arrival Details")
                            .accessibilityIdentifier("barn-more-details")
                    }
                }
                .listRowBackground(ColorTokens.surface)
            }
            .farrierFlowScrollBackground()
            .scrollDismissesKeyboard(.interactively)
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.barnID == nil ? "New Service Location" : "Edit Service Location")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneAccessory(isFocused: focusedField != nil, identifier: "barn-keyboard-done") { focusedField = nil }
            .keepFocusedInputVisible(focusedField)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscription.allowsMutations else { return }
                        if let id = model.save(
                            in: context,
                            analyticsClient: analyticsClient
                        ) {
                            createdBarnID?.wrappedValue = id
                            dismiss()
                        }
                    }
                    .disabled(!subscription.allowsMutations || !model.canSave)
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
            .onAppear { if dismissalBaseline == nil { dismissalBaseline = model.draft } }
            .onChange(of: showsMoreDetails) { _, expanded in
                if !expanded { focusedField = nil }
            }
        }
        .interactiveDismissDisabled(dismissalBaseline.map { $0 != model.draft } ?? false)
    }
}
