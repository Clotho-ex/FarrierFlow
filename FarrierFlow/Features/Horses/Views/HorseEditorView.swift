import SwiftData
import SwiftUI

struct HorseEditorView: View {
    private enum Field: Hashable {
        case name
        case safetyNotes
    }

    private enum Layout {
        static let labelGap: CGFloat = 8
        static let minimumRowHeight: CGFloat = 54
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var path = NavigationPath()
    @State private var model: HorseEditorModel
    @State private var presentedSheet: HorseEditorSheet?
    @State private var createdClientID: PersistentIdentifier?
    @State private var createdBarnID: PersistentIdentifier?
    @State private var showsMoreDetails: Bool
    @State private var selectedDetent: PresentationDetent
    @State private var dismissalBaseline: HorseDraft?
    @State private var showsValidation = false
    @FocusState private var focusedField: Field?
    private let createdHorseID: Binding<PersistentIdentifier?>?

    init(
        horse: Horse? = nil,
        preselectedClientID: PersistentIdentifier? = nil,
        preselectedBarnID: PersistentIdentifier? = nil,
        createdHorseID: Binding<PersistentIdentifier?>? = nil
    ) {
        _model = State(
            initialValue: HorseEditorModel(
                horse: horse,
                preselectedClientID: preselectedClientID,
                preselectedBarnID: preselectedBarnID
            )
        )
        _showsMoreDetails = State(initialValue: horse != nil)
        _selectedDetent = State(initialValue: horse == nil ? .medium : .large)
        self.createdHorseID = createdHorseID
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    labeledField("Horse Name") {
                        TextField(
                            "Horse Name",
                            text: $model.draft.name,
                            prompt: Text(namePrompt)
                                .foregroundStyle(isMissing(.name) ? ColorTokens.destructive : ColorTokens.textSecondary),
                            axis: dynamicTypeSize.isAccessibilitySize ? .vertical : .horizontal
                        )
                        .foregroundStyle(ColorTokens.textPrimary)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focusedField, equals: .name)
                        .onSubmit {
                            focusedField = nil
                        }
                        .accessibilityLabel("Horse Name")
                        .accessibilityIdentifier("horse-name-field")
                        .inputLimit($model.draft.name, maximum: InputLimits.name)
                        .accessibilityHint(Text(requiredMessage(for: .name)), isEnabled: isMissing(.name))
                        .frame(minHeight: SpacingTokens.minimumTouchTarget)
                    }
                    .focusedInputAnchor(Field.name)

                    if model.choicesLoadState == .loaded {
                        relationshipLink(
                            title: "Client",
                            value: selectedClientName,
                            field: .client,
                            route: .client
                        )
                        .accessibilityIdentifier("horse-client-picker")

                        relationshipLink(
                            title: "Service Location",
                            value: selectedBarnName,
                            field: .serviceLocation,
                            route: .serviceLocation
                        )
                        .accessibilityIdentifier("horse-barn-picker")

                        DisclosureGroup(
                            "More Details",
                            isExpanded: $showsMoreDetails
                        ) {
                            Text("Care Defaults")
                                .recordSectionHeading()

                            Stepper(
                                value: $model.draft.appointmentIntervalWeeks,
                                in: 1...52
                            ) {
                                LabeledContent("Appointment Interval") {
                                    Text(
                                        verbatim: AppointmentIntervalFormatter.string(
                                            weeks: model.draft.appointmentIntervalWeeks,
                                            locale: locale
                                        )
                                    )
                                    .foregroundStyle(ColorTokens.textSecondary)
                                }
                            }

                            Picker(
                                "Default Service",
                                selection: $model.draft.defaultServiceID
                            ) {
                                Text("None").tag(PersistentIdentifier?.none)
                                ForEach(model.activeServiceChoices) { service in
                                    Text("\(service.name) · \(formattedPrice(for: service))")
                                        .tag(Optional(service.id))
                                }
                            }
                            .accessibilityIdentifier("horse-default-service-picker")
                            .accessibilityValue(defaultServiceAccessibilityValue)
                            if model.activeServiceChoices.isEmpty {
                                Text(
                                    "No active services are available. You can continue without a default."
                                )
                                .font(.footnote)
                                .foregroundStyle(ColorTokens.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: Layout.labelGap) {
                                Text("Additional Notes")
                                    .font(.caption)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .accessibilityHidden(true)
                                Text("Behavior, handling, or safety details")
                                    .font(.footnote)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                TextEditor(text: $model.draft.safetyNotes)
                                    .frame(minHeight: 88)
                                    .focused($focusedField, equals: .safetyNotes)
                                    .accessibilityLabel("Additional Notes")
                                    .inputLimit($model.draft.safetyNotes, maximum: InputLimits.notes)
                            }
                            .focusedInputAnchor(Field.safetyNotes)
                        }
                        .accessibilityIdentifier("horse-more-details")
                    }
                }
                .listRowBackground(ColorTokens.surface)
                loadStateSection
            }
            .environment(
                \.defaultMinListRowHeight,
                Layout.minimumRowHeight
            )
            .farrierFlowScrollBackground()
            .disabled(!subscription.allowsMutations)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(model.horseID == nil ? "New Horse" : "Edit Horse")
            .toolbarTitleDisplayMode(.inline)
            .keyboardDoneAccessory(isFocused: focusedField != nil, identifier: "horse-keyboard-done") { focusedField = nil }
            .keepFocusedInputVisible(focusedField)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .tint(ColorTokens.brandActionText)
                    .disabled(!subscription.allowsMutations || model.choicesLoadState != .loaded)
                    .accessibilityIdentifier("horse-save-action")
                }
            }
            .navigationDestination(for: HorseEditorRoute.self) {
                selector(for: $0)
                    .onAppear(perform: expandSheet)
            }
            .onAppear {
                model.loadChoices(in: context)
                if dismissalBaseline == nil { dismissalBaseline = model.draft }
            }
            .onChange(of: focusedField) { _, field in
                if field != nil {
                    expandSheet()
                }
            }
            .onChange(of: showsMoreDetails) { _, isExpanded in
                if isExpanded {
                    expandSheet()
                } else if focusedField == .safetyNotes {
                    focusedField = nil
                }
            }
            .sheet(item: $presentedSheet, onDismiss: reloadCreatedRecord) { sheet in
                switch sheet {
                case .client:
                    ClientEditorView(createdClientID: $createdClientID)
                case .serviceLocation:
                    BarnEditorView(createdBarnID: $createdBarnID)
                }
            }
            .alert(item: $model.alert) {
                if let relocation = model.pendingRelocation {
                    Alert(
                        title: Text($0.title), message: Text($0.message),
                        primaryButton: .default(Text("Move Horse")) { save(confirming: relocation) },
                        secondaryButton: .cancel()
                    )
                } else {
                    Alert(title: Text($0.title), message: Text($0.message))
                }
            }
        }
        .presentationDetents(
            [.medium, .large],
            selection: $selectedDetent
        )
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(dismissalBaseline.map { $0 != model.draft } ?? false)
    }

    private func save(confirming relocation: HorseRelocationConfirmation? = nil) {
        guard subscription.allowsMutations else { return }
        guard model.canSave else {
            focusedField = nil
            if model.draft.missingRequiredFields.isEmpty {
                showsMoreDetails = true
                model.alert = FeatureAlert(title: "Default Service Unavailable",
                    message: "Choose an active service or None before saving this horse.")
            } else {
                showsValidation = true
                // Native prompts need an empty value, including a whitespace-only missing name.
                if model.draft.missingRequiredFields.contains(.name) { model.draft.name = "" }
                let message = [HorseRequiredField.name, .client, .serviceLocation]
                    .filter { model.draft.missingRequiredFields.contains($0) }
                    .map { requiredMessage(for: $0) }
                    .joined(separator: " ")
                AccessibilityNotification.Announcement(message).post()
            }
            return
        }
        // Creation must share the parent's cached inverse relationships; moves need a fresh read.
        let savingContext = model.horseID == nil ? context : ModelContext(context.container)
        if let id = model.save(in: savingContext, analyticsClient: analyticsClient, confirming: relocation) {
            createdHorseID?.wrappedValue = id
            dismiss()
        }
    }

    private func isMissing(_ field: HorseRequiredField) -> Bool {
        showsValidation && model.draft.missingRequiredFields.contains(field)
    }

    private var namePrompt: String {
        if dynamicTypeSize.isAccessibilitySize {
            return isMissing(.name)
                ? String(localized: "Required", locale: locale)
                : String(localized: "Enter name", locale: locale)
        }
        return isMissing(.name)
            ? String(localized: "Horse name required", locale: locale)
            : String(localized: "Enter horse name", locale: locale)
    }

    private func requiredMessage(for field: HorseRequiredField) -> String {
        switch field {
        case .name: String(localized: "Enter a horse name.", locale: locale)
        case .client: String(localized: "Select a client.", locale: locale)
        case .serviceLocation: String(localized: "Select a service location.", locale: locale)
        }
    }

    private func reloadCreatedRecord() {
        if let createdClientID {
            self.createdClientID = nil
            model.selectCreatedClient(createdClientID, in: context)
            path = NavigationPath()
        } else if let createdBarnID {
            self.createdBarnID = nil
            model.selectCreatedBarn(createdBarnID, in: context)
            path = NavigationPath()
        }
    }

    private var selectedClientName: String {
        guard let id = model.draft.clientID else {
            return String(localized: "Select Client", locale: locale)
        }
        return model.clients.first { $0.id == id }?.name
            ?? String(localized: "Select Client", locale: locale)
    }

    private var selectedBarnName: String {
        guard let id = model.draft.barnID else {
            return String(localized: "Select", locale: locale)
        }
        return model.barns.first { $0.id == id }?.name
            ?? String(localized: "Select", locale: locale)
    }

    private func relationshipLink(
        title: LocalizedStringKey,
        value: String,
        field: HorseRequiredField,
        route: HorseEditorRoute
    ) -> some View {
        let hasError = isMissing(field)
        let displayedValue = hasError ? String(localized: "Required", locale: locale) : value
        return NavigationLink(value: route) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                    Text(title)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(displayedValue)
                        .foregroundStyle(hasError ? ColorTokens.destructive : ColorTokens.textSecondary)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                LabeledContent {
                    Text(displayedValue)
                        .foregroundStyle(hasError ? ColorTokens.destructive : ColorTokens.textSecondary)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Text(title)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(displayedValue)
        .accessibilityHint(Text(requiredMessage(for: field)), isEnabled: hasError)
    }

    @ViewBuilder
    private func selector(for route: HorseEditorRoute) -> some View {
        switch route {
        case .client:
            HorseRelationshipSelectorView(
                title: "Select Client",
                choices: model.clients.map {
                    HorseRelationshipChoice(
                        id: $0.id,
                        name: $0.name
                    )
                },
                selectedID: model.draft.clientID,
                emptyMessage: "No clients yet.",
                createTitle: "Create New Client",
                createSystemImage: "person.badge.plus",
                onSelect: { id in
                    model.draft.clientID = id
                    returnToEditor()
                },
                onCreate: {
                    presentedSheet = .client
                }
            )
        case .serviceLocation:
            HorseRelationshipSelectorView(
                title: "Select Service Location",
                choices: model.barns.map {
                    HorseRelationshipChoice(
                        id: $0.id,
                        name: $0.name
                    )
                },
                selectedID: model.draft.barnID,
                emptyMessage: "No service locations yet.",
                createTitle: "Create New Service Location",
                createSystemImage: "plus",
                onSelect: { id in
                    model.draft.barnID = id
                    returnToEditor()
                },
                onCreate: {
                    presentedSheet = .serviceLocation
                }
            )
        }
    }

    private func returnToEditor() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    private func expandSheet() {
        guard selectedDetent != .large else { return }
        withAnimation {
            selectedDetent = .large
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let field = VStack(alignment: .leading, spacing: Layout.labelGap) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityHidden(true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if #available(iOS 26.0, *) {
            field.listRowInsets(.vertical, SpacingTokens.related)
        } else {
            field
        }
    }

    private func formattedPrice(for service: ServiceChoice) -> String {
        MoneyFormatter.currency(
            minorUnits: service.defaultAmountMinorUnits,
            currencyCode: service.currencyCode,
            locale: locale
        ) ?? String(localized: "Unavailable", locale: locale)
    }

    private var defaultServiceAccessibilityValue: String {
        guard
            let id = model.draft.defaultServiceID,
            let service = model.activeServiceChoices.first(where: { $0.id == id })
        else {
            return String(localized: "None", locale: locale)
        }
        return String(
            localized: "\(service.name) · \(formattedPrice(for: service))",
            locale: locale
        )
    }

    @ViewBuilder
    private var loadStateSection: some View {
        switch model.choicesLoadState {
        case .loading:
            Section {
                HStack {
                    ProgressView()
                    Text("Loading records…")
                }
            }
            .listRowBackground(ColorTokens.surface)
        case .failed:
            Section {
                ContentUnavailableView {
                    Label("Records Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load clients and service locations.")
                } actions: {
                    Button("Retry") {
                        model.loadChoices(in: context)
                    }
                }
            }
            .listRowBackground(ColorTokens.surface)
        case .loaded:
            EmptyView()
        }
    }
}

private enum HorseEditorSheet: String, Identifiable {
    case client
    case serviceLocation

    var id: String { rawValue }
}

private enum HorseEditorRoute: Hashable {
    case client
    case serviceLocation
}

private struct HorseRelationshipChoice: Identifiable {
    let id: PersistentIdentifier
    let name: String
}

private struct HorseRelationshipSelectorView: View {
    let title: LocalizedStringKey
    let choices: [HorseRelationshipChoice]
    let selectedID: PersistentIdentifier?
    let emptyMessage: LocalizedStringKey
    let createTitle: LocalizedStringKey
    let createSystemImage: String
    let onSelect: (PersistentIdentifier) -> Void
    let onCreate: () -> Void

    var body: some View {
        List {
            Section {
                if choices.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(ColorTokens.textSecondary)
                } else {
                    ForEach(choices) { choice in
                        Button {
                            onSelect(choice.id)
                        } label: {
                            HStack(spacing: SpacingTokens.compact) {
                                Text(choice.name)
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Spacer(minLength: SpacingTokens.compact)
                                if choice.id == selectedID {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(ColorTokens.brandActionText)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            choice.id == selectedID ? .isSelected : []
                        )
                    }
                }
            }
            .listRowBackground(ColorTokens.surface)

            Section {
                Button(action: onCreate) {
                    Label {
                        Text(createTitle)
                    } icon: {
                        Image(systemName: createSystemImage)
                    }
                }
            }
            .listRowBackground(ColorTokens.surface)
        }
        .farrierFlowScrollBackground()
        .navigationTitle(Text(title))
        .toolbarTitleDisplayMode(.inline)
    }
}
