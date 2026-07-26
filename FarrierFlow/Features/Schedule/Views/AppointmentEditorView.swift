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
                Section("Horses") {
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
                Section("Notes") {
                    TextEditor(text: $model.draft.notes)
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
}
