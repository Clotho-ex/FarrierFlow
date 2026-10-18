import SwiftData
import SwiftUI

struct ClientEditorView: View {
    private enum ClientField: Hashable {
        case name
        case phone
        case email
        case notes
    }

    private enum Layout {
        static let labelGap: CGFloat = 4
        static let controlGap: CGFloat = 8
        static let minimumRowHeight: CGFloat = 52
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: ClientEditorModel
    @State private var showsMoreDetails: Bool
    @State private var selectedDetent: PresentationDetent
    @FocusState private var focusedField: ClientField?
    private let createdClientID: Binding<PersistentIdentifier?>?

    init(
        client: Client? = nil,
        createdClientID: Binding<PersistentIdentifier?>? = nil
    ) {
        _model = State(initialValue: ClientEditorModel(client: client))
        _showsMoreDetails = State(initialValue: client != nil)
        _selectedDetent = State(initialValue: client == nil ? .medium : .large)
        self.createdClientID = createdClientID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    labeledField("Client Name") {
                        TextField(
                            "Client Name",
                            text: $model.draft.name,
                            prompt: Text("Add client name")
                                .foregroundStyle(ColorTokens.textSecondary)
                        )
                        .foregroundStyle(ColorTokens.textPrimary)
                        .textContentType(.name)
                        .submitLabel(showsMoreDetails ? .next : .done)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            if showsMoreDetails {
                                focusedField = .phone
                            } else {
                                focusedField = nil
                            }
                        }
                        .accessibilityLabel("Client Name")
                        .accessibilityIdentifier("client-name-field")
                    }

                    Button {
                        showsMoreDetails.toggle()
                    } label: {
                        HStack(spacing: Layout.controlGap) {
                            Text("More Details")
                                .foregroundStyle(ColorTokens.textPrimary)
                            Spacer(minLength: Layout.controlGap)
                            Image(
                                systemName: showsMoreDetails
                                    ? "chevron.up"
                                    : "chevron.down"
                            )
                            .font(.body.weight(.semibold))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("client-more-details")
                    .accessibilityValue(
                        showsMoreDetails ? "Expanded" : "Collapsed"
                    )

                    if showsMoreDetails {
                        labeledField("Phone") {
                            TextField(
                                "Phone",
                                text: $model.draft.phone,
                                prompt: Text("Add phone")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            )
                            .foregroundStyle(ColorTokens.textPrimary)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .focused($focusedField, equals: .phone)
                            .accessibilityLabel("Phone")
                            .accessibilityIdentifier("client-phone-field")
                        }

                        labeledField("Email") {
                            TextField(
                                "Email",
                                text: $model.draft.email,
                                prompt: Text("Add email")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            )
                            .foregroundStyle(ColorTokens.textPrimary)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .notes
                            }
                            .accessibilityLabel("Email")
                            .accessibilityIdentifier("client-email-field")
                        }

                        labeledField("Notes") {
                            TextField(
                                "Client Notes",
                                text: $model.draft.notes,
                                prompt: Text("Add notes")
                                    .foregroundStyle(ColorTokens.textSecondary),
                                axis: .vertical
                            )
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(2...5)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .notes)
                            .onSubmit {
                                focusedField = nil
                            }
                            .accessibilityLabel("Client Notes")
                            .accessibilityIdentifier("client-notes-field")
                        }
                    }
                }
                .listRowBackground(ColorTokens.surface)
            }
            .environment(
                \.defaultMinListRowHeight,
                Layout.minimumRowHeight
            )
            .farrierFlowScrollBackground()
            .disabled(!subscription.allowsMutations)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(model.clientID == nil ? "New Client" : "Edit Client")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .tint(ColorTokens.brandActionText)
                        .disabled(
                            !subscription.allowsMutations || !model.canSave
                        )
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHint("Dismisses the keyboard without saving")
                    .accessibilityIdentifier("client-keyboard-done")
                }
            }
            .onChange(of: focusedField) { _, field in
                if field != nil {
                    expandSheet()
                }
            }
            .onChange(of: showsMoreDetails) { _, isExpanded in
                if isExpanded {
                    expandSheet()
                } else if focusedField != nil, focusedField != .name {
                    focusedField = .name
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
        .presentationDetents(
            [.medium, .large],
            selection: $selectedDetent
        )
        .presentationDragIndicator(.visible)
    }

    private func expandSheet() {
        guard selectedDetent != .large else { return }
        withAnimation {
            selectedDetent = .large
        }
    }

    private func labeledField<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.labelGap) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityHidden(true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        guard subscription.allowsMutations else { return }
        if let id = model.save(
            in: context,
            analyticsClient: analyticsClient
        ) {
            createdClientID?.wrappedValue = id
            dismiss()
        }
    }
}
