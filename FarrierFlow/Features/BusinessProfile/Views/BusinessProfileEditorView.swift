import SwiftData
import SwiftUI

struct BusinessProfileEditorView: View {
    enum Mode {
        case full
        case identity
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(PersistenceMutationCoordinator.self) private var mutationCoordinator
    @State private var model = BusinessProfileEditorModel()
    @FocusState private var focusedField: Field?

    private let onSaved: (() -> Void)?
    private let mode: Mode

    init(mode: Mode = .full, onSaved: (() -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("Loading My Business…")
            case .loaded:
                form
            case .failed:
                ContentUnavailableView {
                    Label(
                        "My Business Unavailable",
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
        .navigationTitle(mode == .identity ? "Your Business" : "My Business")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.loadState == .loaded {
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .identity ? "Continue" : "Save", action: save)
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("business-profile-save-action")
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
                .submitLabel(mode == .identity ? .go : .next)
                .focused($focusedField, equals: .name)
                .onSubmit {
                    if mode == .identity {
                        save()
                    } else {
                        focusedField = .phone
                    }
                }
                .accessibilityIdentifier("business-profile-name-field")
                .accessibilityHint(
                    mode == .identity
                        ? "Required. You can add other business details later."
                        : "Required. Used on future invoices."
                )

                if !model.draft.name.isEmpty,
                   TextNormalization.required(model.draft.name) == nil {
                    Text("Enter a business or farrier name.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Business")
            } footer: {
                if mode == .identity {
                    Text("This name appears on Today and future invoices. Add contact information and defaults later from My Business.")
                } else {
                    Text("A business or farrier name is required.")
                }
            }

            if mode == .full {
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
                    Picker(
                        "Usual Appointment",
                        selection: $model.draft.defaultAppointmentDurationMinutes
                    ) {
                        Text("Ask Every Time").tag(Int?.none)
                        ForEach([30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(Int?.some(minutes))
                        }
                    }

                    Picker(
                        "Invoice Due",
                        selection: $model.draft.defaultInvoiceDueDays
                    ) {
                        Text("No Due Date").tag(Int?.none)
                        ForEach([7, 14, 30], id: \.self) { days in
                            Text("\(days) days").tag(Int?.some(days))
                        }
                    }

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
                    Text("Usual Settings")
                } footer: {
                    Text("Defaults prefill new drafts. You can change or clear them before saving.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        guard model.save(in: context, coordinator: mutationCoordinator) else {
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
