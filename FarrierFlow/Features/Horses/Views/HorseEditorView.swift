import SwiftData
import SwiftUI

struct HorseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: HorseEditorModel
    @State private var presentedSheet: HorseEditorSheet?
    @State private var createdClientID: PersistentIdentifier?
    @State private var showsMoreDetails: Bool
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
                            Text("Add the horse’s owner before saving this horse.")
                                .foregroundStyle(.secondary)
                            Button("Add Client", systemImage: "person.badge.plus") {
                                presentedSheet = .client
                            }
                            .accessibilityIdentifier("horse-add-client")
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
                            presentedSheet = .serviceLocation
                        }
                        DisclosureGroup(
                            "More Details",
                            isExpanded: $showsMoreDetails
                        ) {
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
                                .foregroundStyle(.secondary)
                            }
                            TextEditor(text: $model.draft.safetyNotes)
                                .frame(minHeight: 88)
                                .accessibilityLabel("Safety Notes")
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
                        .accessibilityIdentifier("horse-more-details")
                    }
                }
                loadStateSection
            }
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.horseID == nil ? "New Horse" : "Edit Horse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscription.allowsMutations else { return }
                        if let id = model.save(in: context) {
                            createdHorseID?.wrappedValue = id
                            dismiss()
                        }
                    }
                    .disabled(!subscription.allowsMutations || !model.canSave)
                }
            }
            .onAppear { model.loadChoices(in: context) }
            .sheet(item: $presentedSheet, onDismiss: reloadCreatedRecord) { sheet in
                switch sheet {
                case .client:
                    ClientEditorView(createdClientID: $createdClientID)
                case .serviceLocation:
                    BarnEditorView(createdBarnID: $model.draft.barnID)
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private func reloadCreatedRecord() {
        if let createdClientID {
            self.createdClientID = nil
            model.selectCreatedClient(createdClientID, in: context)
        } else {
            model.loadChoices(in: context)
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

private enum HorseEditorSheet: String, Identifiable {
    case client
    case serviceLocation

    var id: String { rawValue }
}
