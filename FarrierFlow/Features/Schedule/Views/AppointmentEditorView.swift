import SwiftData
import SwiftUI

struct AppointmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: AppointmentEditorModel

    init(appointment: Appointment? = nil) {
        _model = State(initialValue: AppointmentEditorModel(appointment: appointment))
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
                            Text("No service locations available")
                                .foregroundStyle(.secondary)
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
                        }
                    }
                    DatePicker(
                        "Starts",
                        selection: $model.draft.startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField(
                        "Expected Duration (minutes)",
                        text: $model.draft.expectedDurationText
                    )
                    .keyboardType(.numberPad)
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
                            Text("No eligible horses")
                                .foregroundStyle(.secondary)
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
                        }
                    }
                }
                Section("Appointment Notes") {
                    TextEditor(text: $model.draft.notes)
                        .accessibilityLabel("Appointment Notes")
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
                        if model.save(in: context) != nil {
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
                }
            }
            .onAppear { model.load(in: context) }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
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
