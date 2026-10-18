import SwiftData
import SwiftUI

private enum BusinessProfileLayout {
    static let subtitleGap: CGFloat = 4
    static let rowGap: CGFloat = 8
    static let contentGap: CGFloat = 12
    static let sectionGap: CGFloat = 28
    static let symbolSide: CGFloat = 24
    static let rowMinimumHeight: CGFloat = 52
}

struct BusinessProfileEditorView: View {
    enum Mode: Equatable {
        case full
        case identity
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model = BusinessProfileEditorModel()
    @State private var identityContinueFeedbackTrigger = 0
    @State private var showsCurrencyLockExplanation = false
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
        .toolbarTitleDisplayMode(.inline)
        .toolbarVisibility(mode == .full ? .hidden : .automatic, for: .tabBar)
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
            model.load(in: context, locale: locale)
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

            VStack(alignment: .leading, spacing: SpacingTokens.related) {
                Text("Business currency")
                    .font(.headline)

                currencyControl

                Text("Used for services, invoices, payments, PDFs, and exports. Confirm it before adding your first service.")
                    .font(.footnote)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            if !allowsEditing {
                Section {
                    readOnlyNotice
                }
                .listRowBackground(ColorTokens.surface)
            }

            Section {
                VStack(alignment: .leading, spacing: BusinessProfileLayout.subtitleGap) {
                    labeledField("Business or farrier name") {
                        TextField(
                            "Business or farrier name",
                            text: $model.draft.name,
                            prompt: Text("Add business name")
                                .foregroundStyle(ColorTokens.brandActionText)
                        )
                        .foregroundStyle(ColorTokens.textPrimary)
                        .textContentType(.organizationName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = .phone
                        }
                        .accessibilityLabel("Business or farrier name")
                        .accessibilityIdentifier("business-profile-name-field")
                        .accessibilityHint("Required. Used on future invoices.")
                        .disabled(!allowsEditing)
                    }

                    if allowsEditing,
                       !model.draft.name.isEmpty,
                       TextNormalization.required(model.draft.name) == nil {
                        Label(
                            "Enter a business or farrier name.",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.destructive)
                        .accessibilityIdentifier("business-profile-name-error")
                    }
                }

                currencyControl
            } header: {
                Text("Business Details")
            }
            .listRowBackground(ColorTokens.surface)

            Section {
                labeledField("Phone") {
                    TextField(
                        "Phone",
                        text: $model.draft.phone,
                        prompt: Text("Add phone")
                            .foregroundStyle(ColorTokens.brandActionText)
                    )
                    .foregroundStyle(ColorTokens.textPrimary)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .phone)
                    .accessibilityLabel("Phone")
                    .accessibilityIdentifier("business-profile-phone-field")
                    .disabled(!allowsEditing)
                }

                labeledField("Email") {
                    TextField(
                        "Email",
                        text: $model.draft.email,
                        prompt: Text("Add email")
                            .foregroundStyle(ColorTokens.brandActionText)
                    )
                    .foregroundStyle(ColorTokens.textPrimary)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .address
                    }
                    .accessibilityLabel("Email")
                    .accessibilityIdentifier("business-profile-email-field")
                    .disabled(!allowsEditing)
                }

                labeledField("Address") {
                    TextField(
                        "Address",
                        text: $model.draft.address,
                        prompt: Text("Add address")
                            .foregroundStyle(ColorTokens.brandActionText),
                        axis: .vertical
                    )
                    .foregroundStyle(ColorTokens.textPrimary)
                    .textContentType(.fullStreetAddress)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .address)
                    .accessibilityLabel("Address")
                    .accessibilityIdentifier("business-profile-address-field")
                    .disabled(!allowsEditing)
                }
            } header: {
                Text("Contact Information")
            } footer: {
                Text("Optional business contact details.")
            }
            .listRowBackground(ColorTokens.surface)

            Section {
                Picker(
                    "Appointment Duration",
                    selection: $model.draft.defaultAppointmentDurationMinutes
                ) {
                    Text("Ask Every Time").tag(Int?.none)
                    ForEach([30, 45, 60, 90, 120], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(Int?.some(minutes))
                    }
                }
                .tint(ColorTokens.brandActionText)
                .disabled(!allowsEditing)

                Picker(
                    "Invoice Due",
                    selection: $model.draft.defaultInvoiceDueDays
                ) {
                    Text("No Due Date").tag(Int?.none)
                    ForEach([7, 14, 30], id: \.self) { days in
                        Text("\(days) days").tag(Int?.some(days))
                    }
                }
                .tint(ColorTokens.brandActionText)
                .disabled(!allowsEditing)

                labeledField("Default Invoice Note") {
                    TextField(
                        "Default Invoice Note",
                        text: $model.draft.defaultInvoiceNote,
                        prompt: Text("Add default note")
                            .foregroundStyle(ColorTokens.brandActionText),
                        axis: .vertical
                    )
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .defaultInvoiceNote)
                    .accessibilityLabel("Default Invoice Note")
                    .accessibilityHint("Used on future invoices.")
                    .accessibilityIdentifier(
                        "business-profile-default-invoice-note-field"
                    )
                    .disabled(!allowsEditing)
                }
            } header: {
                Text("Appointment & Invoice Defaults")
            } footer: {
                Text("Defaults prefill new drafts and can be adjusted individually.")
            }
            .listRowBackground(ColorTokens.surface)
        }
        .listSectionSpacing(.custom(BusinessProfileLayout.sectionGap))
        .environment(
            \.defaultMinListRowHeight,
            BusinessProfileLayout.rowMinimumHeight
        )
        .farrierFlowScrollBackground()
        .scrollDismissesKeyboard(.interactively)
    }

    private var readOnlyNotice: some View {
        HStack(alignment: .top, spacing: BusinessProfileLayout.contentGap) {
            Image(systemName: subscription.access == .unavailable ? "wifi.exclamationmark" : "lock")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(
                    width: BusinessProfileLayout.symbolSide,
                    height: BusinessProfileLayout.symbolSide
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: BusinessProfileLayout.subtitleGap) {
                Text("Read Only")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(readOnlyMessage)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("business-profile-read-only-notice")
    }

    private var readOnlyMessage: LocalizedStringKey {
        if subscription.access == .unavailable {
            return "Subscription status couldn’t be verified. Your saved business details remain available."
        }
        return "Your saved business details remain available. Subscribe to make changes."
    }

    private func labeledField<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BusinessProfileLayout.subtitleGap) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityHidden(true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var currencyControl: some View {
        switch mode {
        case .full:
            fullFormCurrencyControl
        case .identity:
            identityCurrencyControl
        }
    }

    @ViewBuilder
    private var fullFormCurrencyControl: some View {
        if model.isCurrencyLocked {
            labeledField("Currency") {
                HStack(spacing: BusinessProfileLayout.contentGap) {
                    Text(currencyLabel(for: model.draft.currencyCode))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Spacer(minLength: BusinessProfileLayout.contentGap)
                    Button {
                        showsCurrencyLockExplanation = true
                    } label: {
                        HStack(spacing: BusinessProfileLayout.rowGap) {
                            Image(systemName: "lock.fill")
                                .font(.body.weight(.semibold))
                                .frame(
                                    width: BusinessProfileLayout.symbolSide,
                                    height: BusinessProfileLayout.symbolSide
                                )
                                .accessibilityHidden(true)
                            Text("Locked")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Why currency is locked")
                    .alert(
                        "Currency is Locked",
                        isPresented: $showsCurrencyLockExplanation
                    ) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(
                            "Currency can’t be changed after services or financial records have been added."
                        )
                    }
                }
            }
            .accessibilityIdentifier("business-profile-currency-locked")
        } else {
            labeledField("Currency") {
                Picker("Currency", selection: $model.draft.currencyCode) {
                    ForEach(BusinessCurrency.allCases) { currency in
                        Text(currencyLabel(for: currency.rawValue))
                            .tag(currency.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(ColorTokens.brandActionText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!allowsEditing)
                .accessibilityLabel("Currency")
                .accessibilityIdentifier("business-profile-currency-picker")
                .accessibilityHint("Choose the currency used for business amounts.")
            }
        }
    }

    @ViewBuilder
    private var identityCurrencyControl: some View {
        if model.isCurrencyLocked {
            LabeledContent(
                "Business Currency",
                value: currencyLabel(for: model.draft.currencyCode)
            )
            .accessibilityIdentifier("business-profile-currency-locked")
        } else {
            Picker("Business Currency", selection: $model.draft.currencyCode) {
                ForEach(BusinessCurrency.allCases) { currency in
                    Text(currencyLabel(for: currency.rawValue))
                        .tag(currency.rawValue)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("business-profile-currency-picker")
            .accessibilityHint("Choose the currency used for business amounts.")
        }
    }

    private func currencyLabel(for currencyCode: String) -> String {
        guard let currency = BusinessCurrency(rawValue: currencyCode) else {
            return currencyCode
        }
        return "\(currency.localizedName(in: locale)) (\(currency.rawValue))"
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
