import SwiftData
import SwiftUI

struct BusinessProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model = BusinessProfileEditorModel()
    @FocusState private var focusedField: Field?

    private let onSaved: (() -> Void)?

    init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("Loading Business Profile…")
            case .loaded:
                form
            case .failed:
                ContentUnavailableView {
                    Label(
                        "Business Profile Unavailable",
                        systemImage: "exclamationmark.circle"
                    )
                } description: {
                    Text(
                        "FarrierFlow couldn’t load your business profile. Try again."
                    )
                } actions: {
                    Button("Retry") {
                        model.load(in: context)
                    }
                }
            }
        }
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.loadState == .loaded {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!model.canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
        .task {
            model.load(in: context)
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField(
                    "Business or Farrier Name",
                    text: $model.draft.name
                )
                .textContentType(.organizationName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focusedField, equals: .name)
                .onSubmit {
                    focusedField = .phone
                }
                .accessibilityIdentifier("business-profile-name-field")
                .accessibilityHint("Required. Used on future invoices.")

                if !model.draft.name.isEmpty,
                   TextNormalization.required(model.draft.name) == nil {
                    Text("Enter a business or farrier name.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Business")
            } footer: {
                Text("A business or farrier name is required.")
            }

            Section {
                TextField("Phone", text: $model.draft.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .phone)
                    .accessibilityIdentifier("business-profile-phone-field")

                TextField("Email", text: $model.draft.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .address
                    }
                    .accessibilityIdentifier("business-profile-email-field")

                TextField(
                    "Address",
                    text: $model.draft.address,
                    axis: .vertical
                )
                .textContentType(.fullStreetAddress)
                .lineLimit(2...4)
                .focused($focusedField, equals: .address)
                .accessibilityIdentifier("business-profile-address-field")
            } header: {
                Text("Contact Information")
            } footer: {
                Text("Phone, email, and address are optional.")
            }

            Section {
                TextField(
                    "Default Invoice Note",
                    text: $model.draft.defaultInvoiceNote,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .focused($focusedField, equals: .defaultInvoiceNote)
                .accessibilityHint("Used on future invoices.")
                .accessibilityIdentifier(
                    "business-profile-default-invoice-note-field"
                )
            } header: {
                Text("Default Invoice Note")
            } footer: {
                Text("This optional note is added to future invoices.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        guard model.save(in: context) else {
            return
        }

        focusedField = nil
        onSaved?()
        dismiss()
    }
}

private extension BusinessProfileEditorView {
    enum Field: Hashable {
        case name
        case phone
        case email
        case address
        case defaultInvoiceNote
    }
}
