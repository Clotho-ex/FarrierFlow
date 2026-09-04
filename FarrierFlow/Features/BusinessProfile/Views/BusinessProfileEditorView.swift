import SwiftData
import SwiftUI

struct BusinessProfileEditorView: View {
    enum Mode {
        case full
        case identity
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model = BusinessProfileEditorModel()
    @State private var identityContinueFeedbackTrigger = 0
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
                editor
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
            if allowsEditing,
               model.loadState == .loaded,
               mode == .full {
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .identity ? "Continue" : "Save", action: save)
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("business-profile-save-action")
                }
            }
            if allowsEditing,
               model.loadState == .loaded,
               mode == .full {
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
            if mode == .identity {
                await Task.yield()
                focusedField = .name
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch mode {
        case .full:
            fullForm
        case .identity:
            identityEditor
        }
    }

    private var identityEditor: some View {
        OnboardingPinnedTitleScrollView("Your Business") {
            VStack(spacing: SpacingTokens.hero) {
                OnboardingHeroTitle(title: "Your Business")
                identityGroup
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .containerRelativeFrame(.vertical, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .onboardingEntrance()
        }
        .accessibilityIdentifier("onboarding-business")
        .scrollDismissesKeyboard(.interactively)
        .defaultFocus($focusedField, .name)
        .safeAreaInset(edge: .bottom) {
            Button(action: continueFromIdentitySetup) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .farrierFlowPrimaryAction()
            .controlSize(.large)
            .disabled(!canSaveCurrentMode)
            .accessibilityIdentifier("business-profile-save-action")
            .sensoryFeedback(
                .impact(weight: .medium),
                trigger: identityContinueFeedbackTrigger
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .tint(ColorTokens.brandActionText)
    }

    private var identityGroup: some View {
        VStack(spacing: SpacingTokens.section) {
            VStack(spacing: SpacingTokens.compact) {
                Text("Make it yours.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityAddTraits(.isHeader)

                Text("Start with the name your clients know and trust.")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: SpacingTokens.related) {
                Text("Business name")
                    .font(.headline)

                TextField(
                    "Business or farrier name",
                    text: $model.draft.name
                )
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .padding(.horizontal, SpacingTokens.standard)
                .frame(minHeight: 58)
                .background(
                    ColorTokens.surfaceElevated,
                    in: RoundedRectangle(
                        cornerRadius: 13,
                        style: .continuous
                    )
                )
                .fieldBookElevation()
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 13,
                        style: .continuous
                    )
                    .stroke(
                        identityFieldBorderColor,
                        lineWidth: identityFieldBorderWidth
                    )
                    .animation(
                        .easeOut(duration: 0.16),
                        value: focusedField == .name
                    )
                }
                .textContentType(.organizationName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focusedField, equals: .name)
                .onSubmit(continueFromIdentitySetup)
                .accessibilityIdentifier("business-profile-name-field")
                .accessibilityHint(
                    "Required. Use letters, numbers, and spaces only."
                )

                if let identityNameErrorMessage {
                    Label(
                        identityNameErrorMessage,
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(ColorTokens.destructive)
                    .accessibilityIdentifier("business-profile-name-error")
                }

                Text("Appears on invoices. You can change it later.")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier(
                    "onboarding-business-introduction"
                )
            }
        }
        .frame(maxWidth: 480)
    }

    private func continueFromIdentitySetup() {
        guard canSaveCurrentMode else { return }
        identityContinueFeedbackTrigger += 1
        save()
    }

    private var fullForm: some View {
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
                        .foregroundStyle(ColorTokens.destructive)
                }
            } header: {
                Text("Business")
            } footer: {
                Text("A business or farrier name is required.")
            }
            .listRowBackground(ColorTokens.surface)

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
            .listRowBackground(ColorTokens.surface)

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
            .listRowBackground(ColorTokens.surface)
        }
        .farrierFlowScrollBackground()
        .disabled(!allowsEditing)
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        guard allowsEditing else { return }
        if mode == .identity {
            guard let name = try? OnboardingBusinessNameRules.validated(
                model.draft.name
            ) else {
                return
            }
            model.draft.name = name
        }
        guard model.save(in: context) else {
            return
        }

        focusedField = nil
        onSaved?()
        if mode == .full {
            dismiss()
        }
    }

    private var allowsEditing: Bool {
        mode == .identity || subscription.allowsMutations
    }

    private var canSaveCurrentMode: Bool {
        switch mode {
        case .full:
            model.canSave
        case .identity:
            model.loadState == .loaded && identityNameValidationError == nil
        }
    }

    private var identityNameValidationError: OnboardingBusinessNameValidationError? {
        do {
            _ = try OnboardingBusinessNameRules.validated(model.draft.name)
            return nil
        } catch let error as OnboardingBusinessNameValidationError {
            return error
        } catch {
            return .required
        }
    }

    private var identityNameErrorMessage: LocalizedStringKey? {
        guard !model.draft.name.isEmpty else { return nil }
        switch identityNameValidationError {
        case .required:
            return "Enter a business or farrier name."
        case .unsupportedCharacters:
            return "Use letters, numbers, and spaces only."
        case .vulgarity:
            return "Choose a professional business name."
        case nil:
            return nil
        }
    }

    private var identityFieldBorderColor: Color {
        if identityNameErrorMessage != nil {
            return ColorTokens.destructive
        }
        return focusedField == .name
            ? ColorTokens.brandPrimary
            : ColorTokens.border
    }

    private var identityFieldBorderWidth: CGFloat {
        focusedField == .name || identityNameErrorMessage != nil ? 2 : 1
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
