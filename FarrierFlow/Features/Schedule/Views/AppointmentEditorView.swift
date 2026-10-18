import SwiftData
import SwiftUI

struct AppointmentEditorView: View {
    private enum Field: Hashable {
        case duration
        case notes
    }

    private enum Layout {
        static let minimumRowHeight: CGFloat = 56
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @FocusState private var focusedField: Field?
    @State private var model: AppointmentEditorModel
    @State private var showsBarnEditor = false
    @State private var createdBarnID: PersistentIdentifier?
    @State private var showsHorseEditor = false
    @State private var createdHorseID: PersistentIdentifier?
    @State private var showsServiceEditor = false
    @State private var createdServiceID: PersistentIdentifier?
    @State private var serviceHorseID: PersistentIdentifier?
    @State private var showsMoreDetails: Bool
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
        _showsMoreDetails = State(initialValue: appointment != nil)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appointment") {
                    if model.hasVisit {
                        LabeledContent(
                            "Service Location",
                            value: model.lockedBarnName ?? "Unavailable"
                        )
                        Text("The service location and horses are fixed after work starts.")
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                    } else if model.loadState == .loaded {
                        if model.barns.isEmpty {
                            Text("Add a service location before scheduling an appointment.")
                                .foregroundStyle(ColorTokens.textSecondary)
                            Button("Add Service Location", systemImage: "plus") {
                                focusedField = nil
                                showsBarnEditor = true
                            }
                            .accessibilityIdentifier("appointment-add-service-location")
                        } else {
                            Picker(
                                "Service Location",
                                selection: Binding(
                                    get: { model.draft.barnID },
                                    set: { model.selectBarn($0, in: context) }
                                )
                            ) {
                                Text("Select Service Location").tag(PersistentIdentifier?.none)
                                ForEach(model.barns, id: \.persistentModelID) {
                                    Text($0.name).tag(Optional($0.persistentModelID))
                                }
                            }
                            .accessibilityIdentifier("appointment-barn-picker")
                            .accessibilityValue(
                                model.barns.first {
                                    $0.persistentModelID == model.draft.barnID
                                }?.name ?? String(localized: "Select Service Location")
                            )
                        }
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
                                    if model.draft.selectedHorseIDs.contains(horse.persistentModelID) {
                                        servicePicker(for: horse)
                                    }
                                }
                                if model.saveRequirement == .horse {
                                    Text("Select at least one horse.")
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                            Button("Add Horse", systemImage: "plus") {
                                focusedField = nil
                                showsHorseEditor = true
                            }
                            .accessibilityIdentifier("appointment-add-horse")
                        }
                    } header: {
                        HStack {
                            Text("Horses")
                            Spacer()
                            if showsHorseSelectionCount {
                                Text(
                                    "\(model.draft.selectedHorseIDs.count) of \(model.eligibleHorses.count) selected"
                                )
                                .textCase(nil)
                            }
                        }
                    }
                    .listRowBackground(ColorTokens.surface)
                }
                Section {
                    DisclosureGroup(
                        "More Details",
                        isExpanded: $showsMoreDetails
                    ) {
                        TextField(
                            "Expected Duration (minutes)",
                            text: $model.draft.expectedDurationText
                        )
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .duration)
                        if model.appliedOwnerDurationDefault {
                            Text("Your typical appointment duration was prefilled. You can change or clear it.")
                                .font(.footnote)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        appointmentRequirementGuidance
                        TextEditor(text: $model.draft.notes)
                            .frame(minHeight: 88)
                            .focused($focusedField, equals: .notes)
                            .accessibilityLabel("Appointment Notes")
                    }
                    .accessibilityIdentifier("appointment-more-details")
                }
                .listRowBackground(ColorTokens.surface)
            }
            .environment(
                \.defaultMinListRowHeight,
                Layout.minimumRowHeight
            )
            .listSectionSpacing(.custom(SpacingTokens.recordSection))
            .farrierFlowScrollBackground()
            .scrollDismissesKeyboard(.interactively)
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.appointmentID == nil ? "New Appointment" : "Edit Appointment")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHint("Dismisses the keyboard without saving")
                        .accessibilityIdentifier("appointment-keyboard-done")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscription.allowsMutations else { return }
                        if let appointmentID = model.save(
                            in: context,
                            analyticsClient: analyticsClient
                        ) {
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
                if model.appliedOwnerDurationDefault {
                    showsMoreDetails = true
                }
            }
            .sheet(isPresented: $showsBarnEditor, onDismiss: selectCreatedBarn) {
                BarnEditorView(createdBarnID: $createdBarnID)
            }
            .sheet(isPresented: $showsServiceEditor, onDismiss: selectCreatedService) {
                ServiceEditorView(createdServiceID: $createdServiceID)
            }
            .sheet(isPresented: $showsHorseEditor, onDismiss: selectCreatedHorse) {
                HorseEditorView(
                    preselectedBarnID: model.draft.barnID,
                    createdHorseID: $createdHorseID
                )
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func servicePicker(for horse: Horse) -> some View {
        let horseID = horse.persistentModelID
        let selection = Binding<PersistentIdentifier?>(
            get: { model.draft.serviceIDsByHorse[horseID] },
            set: { model.draft.serviceIDsByHorse[horseID] = $0 }
        )
        Picker("Service", selection: selection) {
            if let service = horse.defaultService {
                Text("Horse Default: \(service.name)")
                    .tag(PersistentIdentifier?.none)
            } else {
                Text("Choose During Visit").tag(PersistentIdentifier?.none)
            }
            ForEach(model.services.filter {
                !$0.isArchived || $0.persistentModelID == selection.wrappedValue
            }, id: \.persistentModelID) { service in
                Text(service.name).tag(Optional(service.persistentModelID))
            }
        }
        .accessibilityLabel("Service for \(horse.name)")
        .accessibilityValue(
            model.services.first { $0.persistentModelID == selection.wrappedValue }?.name
                ?? horse.defaultService?.name
                ?? String(localized: "Choose During Visit")
        )
        .accessibilityIdentifier("appointment-service-\(horse.name)")
        if model.services.allSatisfy(\.isArchived) {
            Button("Add Service", systemImage: "plus") {
                focusedField = nil
                serviceHorseID = horseID
                showsServiceEditor = true
            }
            .accessibilityIdentifier("appointment-add-service-\(horse.name)")
        }
    }

    private func selectCreatedService() {
        defer {
            createdServiceID = nil
            serviceHorseID = nil
        }
        guard let serviceID = createdServiceID, let horseID = serviceHorseID else { return }
        model.load(in: context)
        if model.draft.selectedHorseIDs.contains(horseID) {
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

    private func selectCreatedHorse() {
        guard let createdHorseID else { return }
        self.createdHorseID = nil
        model.selectCreatedHorse(createdHorseID, in: context)
    }

    @ViewBuilder
    private var appointmentRequirementGuidance: some View {
        switch model.saveRequirement {
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
