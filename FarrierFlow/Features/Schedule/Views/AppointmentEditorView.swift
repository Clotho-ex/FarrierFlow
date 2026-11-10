import SwiftData
import SwiftUI

struct AppointmentEditorView: View {
    private enum Field: Hashable {
        case duration
        case notes
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appointmentSaved) private var appointmentSaved
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @FocusState private var focusedField: Field?
    @State private var model: AppointmentEditorModel
    @State private var showsBarnEditor = false
    @State private var createdBarnID: PersistentIdentifier?
    @State private var showsServiceEditor = false
    @State private var createdServiceID: PersistentIdentifier?
    @State private var serviceHorseID: PersistentIdentifier?
    @State private var showsAdditionalDetails: Bool
    @State private var dismissalBaseline: AppointmentDraft?
    private let onSaved: ((PersistentIdentifier) -> Void)?

    init(
        appointment: Appointment? = nil,
        seed: NextAppointmentSeed? = nil,
        onSaved: ((PersistentIdentifier) -> Void)? = nil
    ) {
        _model = State(
            initialValue: AppointmentEditorModel(
                appointment: appointment,
                seed: seed
            )
        )
        _showsAdditionalDetails = State(initialValue: appointment != nil)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                RecordSection(Text("Appointment")) {
                    if model.hasVisit {
                        LabeledContent(
                            "Service Location",
                            value: model.lockedBarnName ?? "Unavailable"
                        )
                        Text("The service location and horses are fixed after work starts.")
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                    } else if model.loadState == .loaded {
                        locationMenu
                    }
                    DatePicker(
                        "Starts",
                        selection: $model.draft.startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    if model.hasFollowUpSuggestion {
                        Text(
                            "Suggested start based on the horses’ appointment intervals. You can change it."
                        )
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .listRowBackground(ColorTokens.surface)
                loadStateSection
                if model.loadState == .loaded {
                    Section {
                        if model.hasVisit {
                            Text(model.lockedHorseNames.formatted(.list(type: .and)))
                        } else if model.draft.barnID == nil {
                            Label {
                                Text("Choose a service location above to see its horses.")
                            } icon: {
                                Image(systemName: "info.circle")
                                    .accessibilityHidden(true)
                            }
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                        } else {
                            if model.eligibleHorses.isEmpty {
                                Text(
                                    "Add or move a horse to this service location before scheduling an appointment."
                                )
                                    .foregroundStyle(ColorTokens.textSecondary)
                            } else {
                                ForEach(model.eligibleHorses, id: \.persistentModelID) { horse in
                                    HorseSelectionRow(
                                        horse: horse,
                                        isSelected: model.draft.selectedHorseIDs.contains(
                                            horse.persistentModelID
                                        )
                                    ) {
                                        model.toggleHorse(horse.persistentModelID)
                                    }
                                    .accessibilityIdentifier(
                                        "appointment-horse-\(horse.name)"
                                    )
                                }
                                if model.saveRequirement == .horse {
                                    Text("Select at least one horse.")
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                        }
                    } header: {
                        sectionHeaderLayout {
                            Text("Horses").recordSectionHeading()
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            if showsHorseSelectionCount {
                                Text(
                                    "\(model.draft.selectedHorseIDs.count) of \(model.eligibleHorses.count) selected"
                                )
                                .rollingStateText(value: "\(model.draft.selectedHorseIDs.count)-\(model.eligibleHorses.count)")
                                .font(Typography.sectionHeading)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .textCase(nil)
                            }
                        }
                    }
                    .listRowBackground(ColorTokens.surface)
                }
                if !model.hasVisit, model.loadState == .loaded,
                   !model.draft.selectedHorseIDs.isEmpty {
                    Section {
                        ForEach(model.eligibleHorses.filter {
                            model.draft.selectedHorseIDs.contains($0.persistentModelID)
                        }, id: \.persistentModelID) { horse in
                            serviceMenu(for: horse)
                        }
                    } header: {
                        sectionHeaderLayout {
                            Text("Planned Services").recordSectionHeading()
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            Text("Optional")
                                .font(Typography.sectionHeading)
                                .textCase(nil)
                        }
                    }
                    .listRowBackground(ColorTokens.surface)
                }
                Section {
                    DisclosureGroup(isExpanded: $showsAdditionalDetails) {
                        EmptyView()
                    } label: {
                        Text("Additional Details")
                            .accessibilityIdentifier("appointment-additional-details")
                    }
                    if showsAdditionalDetails {
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text("Expected Duration")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .accessibilityHidden(true)
                            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
                                // Fit short input to its text; keep long values within the row.
                                Text(verbatim: model.draft.expectedDurationText.isEmpty
                                     ? String(localized: "Optional", locale: locale)
                                     : model.draft.expectedDurationText)
                                .font(.body)
                                .lineLimit(1)
                                .padding(.trailing, SpacingTokens.rowContent)
                                .hidden()
                                .overlay(alignment: .leading) {
                                    TextField("Optional", text: $model.draft.expectedDurationText)
                                        .font(.body)
                                        .accessibilityLabel("Expected Duration (minutes)")
                                        .accessibilityIdentifier("appointment-duration")
                                        .onChange(of: model.draft.expectedDurationText) { previous, value in
                                            model.draft.expectedDurationText = InputLimits.accepting(value, previous: previous, maximum: InputLimits.duration, rejectOverflow: true)
                                        }
                                        .keyboardType(.numberPad)
                                        .focused($focusedField, equals: .duration)
                                }
                                Text("Minutes")
                                    .font(.caption)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .accessibilityHidden(true)
                                    .accessibilityIdentifier("appointment-duration-unit")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: SpacingTokens.minimumTouchTarget, alignment: .leading)
                        .focusedInputAnchor(Field.duration)
                        .contentShape(.rect)
                        .simultaneousGesture(TapGesture().onEnded {
                            focusedField = .duration
                        })
                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                            Text("Appointment Notes")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .accessibilityHidden(true)
                            TextEditor(text: $model.draft.notes)
                                .frame(minHeight: 88)
                                .focused($focusedField, equals: .notes)
                                .accessibilityLabel("Appointment Notes")
                                .inputLimit($model.draft.notes, maximum: InputLimits.notes)
                        }
                        .focusedInputAnchor(Field.notes)
                    }
                } footer: {
                    appointmentRequirementGuidance
                }
                .listRowBackground(ColorTokens.surface)
            }
            .listSectionSpacing(.custom(SpacingTokens.section))
            .farrierFlowScrollBackground()
            .scrollDismissesKeyboard(.interactively)
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.appointmentID == nil ? "New Appointment" : "Edit Appointment")
            .toolbarTitleDisplayMode(.inline)
            .keyboardDoneAccessory(isFocused: focusedField != nil, identifier: "appointment-keyboard-done") { focusedField = nil }
            .keepFocusedInputVisible(focusedField)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscription.allowsMutations else { return }
                        if let appointmentID = model.save(
                            in: context,
                            analyticsClient: analyticsClient
                        ) {
                            appointmentSaved()
                            onSaved?(appointmentID)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .tint(ColorTokens.brandActionText)
                    .disabled(!subscription.allowsMutations || !model.canSave)
                }
            }
            .onAppear {
                model.load(in: context)
                if dismissalBaseline == nil { dismissalBaseline = model.draft }
            }
            .onChange(of: showsAdditionalDetails) { _, isExpanded in
                if !isExpanded {
                    focusedField = nil
                }
            }
            .sheet(isPresented: $showsBarnEditor, onDismiss: selectCreatedBarn) {
                BarnEditorView(createdBarnID: $createdBarnID)
            }
            .sheet(isPresented: $showsServiceEditor, onDismiss: selectCreatedService) {
                ServiceEditorView(createdServiceID: $createdServiceID)
            }

            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(dismissalBaseline.map { $0 != model.draft } ?? false)
    }

    private var sectionHeaderLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.rowContent))
        } else {
            AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        }
    }

    private var locationMenu: some View {
        Menu {
            Picker("Service Location", selection: Binding(
                get: { model.draft.barnID },
                set: { model.selectBarn($0, in: context) }
            )) {
                Text("Select Service Location").tag(PersistentIdentifier?.none)
                ForEach(model.barns, id: \.persistentModelID) { barn in
                    Text(verbatim: barn.name).tag(Optional(barn.persistentModelID))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Create New Location…") {
                focusedField = nil
                showsBarnEditor = true
            }
            .accessibilityIdentifier("appointment-create-location")
        } label: {
            LabeledContent("Service Location") {
                HStack(spacing: SpacingTokens.compact) {
                    Text(verbatim: selectedBarnName)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityLabel("Service Location")
        .accessibilityIdentifier("appointment-barn-picker")
        .accessibilityValue(selectedBarnName)
    }

    private var selectedBarnName: String {
        model.barns.first { $0.persistentModelID == model.draft.barnID }?.name
            ?? String(localized: "Select Service Location")
    }

    private func serviceMenu(for horse: Horse) -> some View {
        let horseID = horse.persistentModelID
        let selection = Binding<PersistentIdentifier?>(
            get: { model.draft.serviceIDsByHorse[horseID] },
            set: { model.draft.serviceIDsByHorse[horseID] = $0 }
        )
        let selectedName = model.services.first {
            $0.persistentModelID == selection.wrappedValue
        }?.name
            ?? horse.defaultService.map { String(localized: "Horse Default: \($0.name)") }
            ?? String(localized: "Choose Service")
        return Menu {
            Picker("Service", selection: selection) {
                if let service = horse.defaultService {
                    Text("Horse Default: \(service.name)")
                        .tag(PersistentIdentifier?.none)
                } else {
                    Text("Choose Service").tag(PersistentIdentifier?.none)
                }
                ForEach(model.services.filter {
                    !$0.isArchived || $0.persistentModelID == selection.wrappedValue
                }, id: \.persistentModelID) { service in
                    Text(verbatim: service.name).tag(Optional(service.persistentModelID))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Create New Service…") {
                focusedField = nil
                serviceHorseID = horseID
                showsServiceEditor = true
            }
            .accessibilityIdentifier("appointment-create-service")
        } label: {
            HStack(spacing: SpacingTokens.compact) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                        Text(verbatim: horse.name)
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text(verbatim: selectedName)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LabeledContent {
                        Text(verbatim: selectedName)
                            .foregroundStyle(ColorTokens.textSecondary)
                    } label: {
                        Text(verbatim: horse.name)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .accessibilityLabel("Service for \(horse.name)")
        .accessibilityValue(selectedName)
        .accessibilityIdentifier("appointment-service-\(horse.name)")
    }

    private func selectCreatedService() {
        defer {
            createdServiceID = nil
            serviceHorseID = nil
        }
        guard let serviceID = createdServiceID else { return }
        model.load(in: context)
        if let horseID = serviceHorseID, model.draft.selectedHorseIDs.contains(horseID) {
            model.draft.serviceIDsByHorse[horseID] = serviceID
        }
    }

    private var showsHorseSelectionCount: Bool {
        !model.hasVisit
            && model.draft.barnID != nil
            && !model.eligibleHorses.isEmpty
    }

    private func selectCreatedBarn() {
        guard let createdBarnID else { return }
        self.createdBarnID = nil
        model.selectCreatedBarn(createdBarnID, in: context)
    }

    @ViewBuilder
    private var appointmentRequirementGuidance: some View {
        switch model.saveRequirement {
        case .notesTooLong:
            Text("Maximum \(InputLimits.notes) characters.").font(.footnote)
        case .expectedDuration:
            Text("Enter a duration greater than zero, or leave it blank.")
                .font(.footnote.weight(.semibold))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var loadStateSection: some View {
        switch model.loadState {
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
                    Label("Appointment Records Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load service locations and horses.")
                } actions: {
                    Button("Retry") {
                        model.load(in: context)
                    }
                }
            }
            .listRowBackground(ColorTokens.surface)
        case .loaded:
            EmptyView()
        }
    }
}
