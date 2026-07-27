import SwiftData
import SwiftUI

struct HorseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var model: HorseEditorModel
    @State private var showsBarnEditor = false

    init(
        horse: Horse? = nil,
        preselectedClientID: PersistentIdentifier? = nil,
        preselectedBarnID: PersistentIdentifier? = nil
    ) {
        _model = State(
            initialValue: HorseEditorModel(
                horse: horse,
                preselectedClientID: preselectedClientID,
                preselectedBarnID: preselectedBarnID
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Horse") {
                    TextField("Name", text: $model.draft.name)
                        .accessibilityIdentifier("horse-name-field")
                    if model.choicesLoadState == .loaded {
                        if model.clients.isEmpty {
                            Text("No clients available")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Client", selection: $model.draft.clientID) {
                                Text("Select Client").tag(PersistentIdentifier?.none)
                                ForEach(model.clients, id: \.persistentModelID) {
                                    Text($0.name).tag(Optional($0.persistentModelID))
                                }
                            }
                            .accessibilityIdentifier("horse-client-picker")
                        }
                        if model.barns.isEmpty {
                            Text("No service locations available")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Service Location", selection: $model.draft.barnID) {
                                Text("Select Service Location").tag(PersistentIdentifier?.none)
                                ForEach(model.barns, id: \.persistentModelID) {
                                    Text($0.name).tag(Optional($0.persistentModelID))
                                }
                            }
                            .accessibilityIdentifier("horse-barn-picker")
                        }
                        Button("Create Service Location", systemImage: "plus") {
                            showsBarnEditor = true
                        }
                    }
                }
                loadStateSection
                Section("Safety Notes") {
                    TextEditor(text: $model.draft.safetyNotes)
                        .accessibilityLabel("Safety Notes")
                }
                Section("Appointment Interval") {
                    Stepper(
                        "\(model.draft.appointmentIntervalWeeks) weeks",
                        value: $model.draft.appointmentIntervalWeeks,
                        in: 1...52
                    )
                }
            }
            .navigationTitle(model.horseID == nil ? "New Horse" : "Edit Horse")
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
            .onAppear { model.loadChoices(in: context) }
            .sheet(isPresented: $showsBarnEditor, onDismiss: {
                model.loadChoices(in: context)
            }) {
                BarnEditorView(createdBarnID: $model.draft.barnID)
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
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
        case .loaded:
            EmptyView()
        }
    }
}
