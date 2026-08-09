import SwiftData
import SwiftUI

struct AppointmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(PersistenceMutationCoordinator.self) private var mutationCoordinator
    @State private var model: AppointmentEditorModel
    @State private var showsBarnEditor = false
    @State private var createdBarnID: PersistentIdentifier?
    @State private var showsHorseEditor = false
    @State private var createdHorseID: PersistentIdentifier?
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
                            .foregroundStyle(.secondary)
                    } else if model.loadState == .loaded {
                        if model.barns.isEmpty {
                            Text("Add a service location before scheduling an appointment.")
                                .foregroundStyle(.secondary)
                            Button("Add Service Location", systemImage: "plus") {
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
                            .foregroundStyle(.secondary)
                    }
                    DisclosureGroup(
                        "More Details",
                        isExpanded: $showsMoreDetails
                    ) {
                        TextField(
                            "Expected Duration (minutes)",
                            text: $model.draft.expectedDurationText
                        )
                        .keyboardType(.numberPad)
                        if model.appliedOwnerDurationDefault {
                            Text("Your typical appointment duration was prefilled. You can change or clear it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        appointmentRequirementGuidance
                        TextEditor(text: $model.draft.notes)
                            .frame(minHeight: 88)
                            .accessibilityLabel("Appointment Notes")
                    }
                    .accessibilityIdentifier("appointment-more-details")
                }
                loadStateSection
                if model.loadState == .loaded {
                    Section("Horses") {
                        if model.hasVisit {
                            Text(model.lockedHorseNames.formatted(.list(type: .and)))
                        } else if model.draft.barnID == nil {
                            Text("Select a service location to choose horses.")
                                .foregroundStyle(.secondary)
                        } else if model.eligibleHorses.isEmpty {
                            Text(
                                "Add or move a horse to this service location before scheduling an appointment."
                            )
                                .foregroundStyle(.secondary)
                            Button("Add Horse", systemImage: "plus") {
                                showsHorseEditor = true
                            }
                            .accessibilityIdentifier("appointment-add-horse")
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
                }
            }
            .navigationTitle(model.appointmentID == nil ? "New Appointment" : "Edit Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let appointmentID = model.save(
                            in: context,
                            coordinator: mutationCoordinator
                        ) {
                            onSaved?(appointmentID)
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
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
        case .loaded:
            EmptyView()
        }
    }
}
