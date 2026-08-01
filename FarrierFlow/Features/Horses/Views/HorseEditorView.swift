import SwiftData
import SwiftUI

struct HorseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model: HorseEditorModel
    @State private var showsBarnEditor = false
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
        self.createdHorseID = createdHorseID
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
                        Picker("Default Service", selection: $model.draft.defaultServiceID) {
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
                                "No active services are available. You can continue without a default or add one from Clients, More, Services."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                        value: $model.draft.appointmentIntervalWeeks,
                        in: 1...52
                    ) {
                        Text(
                            verbatim: AppointmentIntervalFormatter.string(
                                weeks: model.draft.appointmentIntervalWeeks,
                                locale: locale
                            )
                        )
                    }
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
                        if let id = model.save(in: context) {
                            createdHorseID?.wrappedValue = id
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

    private func formattedPrice(for service: ServiceChoice) -> String {
        MoneyFormatter.usd(
            minorUnits: service.defaultAmountMinorUnits,
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
