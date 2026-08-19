import SwiftData
import SwiftUI

struct InvoiceCreationView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model: InvoiceCreationModel
    @FocusState private var isNoteFocused: Bool

    let clientID: PersistentIdentifier
    let onGenerated: (PersistentIdentifier) -> Void

    init(
        clientID: PersistentIdentifier,
        initiallySelectedVisitID: PersistentIdentifier? = nil,
        onGenerated: @escaping (PersistentIdentifier) -> Void
    ) {
        self.clientID = clientID
        self.onGenerated = onGenerated
        _model = State(
            initialValue: InvoiceCreationModel(
                clientID: clientID,
                initiallySelectedVisitID: initiallySelectedVisitID
            )
        )
    }

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("Loading Invoice…")
            case .failed:
                ContentUnavailableView {
                    Label("Invoice Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load this invoice. Try again.")
                } actions: {
                    Button("Retry", action: reload)
                }
            case .loaded:
                form
            }
        }
        .navigationTitle("Create Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Generate", action: generate)
                    .disabled(!model.canGenerate)
                    .accessibilityIdentifier("invoice-generate-action")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNoteFocused = false }
            }
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
        .task(id: clientID, reload)
    }

    private var form: some View {
        Form {
            Section("Client") {
                Text(model.clientName ?? "")
            }
            Section {
                Button("Select All", action: model.selectAll)
                    .disabled(model.visitChoices.isEmpty)
                    .accessibilityIdentifier("invoice-select-all-action")
                ForEach(Array(model.visitChoices.enumerated()), id: \.element.id) { index, choice in
                    InvoiceVisitSelectionRow(
                        choice: choice,
                        isSelected: model.draft?.selectedVisitIDs.contains(choice.id) == true
                    ) {
                        model.toggleVisit(choice.id)
                    }
                    .accessibilityIdentifier("invoice-visit-choice-\(index)")
                }
                if model.visitChoices.isEmpty {
                    Text("No completed, uninvoiced work is available for this client.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Completed Visits")
            } footer: {
                Text("Selecting a visit includes all eligible recorded work for this client.")
            }
            Section("Selection Summary") {
                LabeledContent("Visits") {
                    Text(model.selectionSummary?.visitCount ?? 0, format: .number)
                }
                .accessibilityIdentifier("invoice-selection-visit-count")
                LabeledContent("Recorded Services") {
                    Text(model.selectionSummary?.recordedServiceCount ?? 0, format: .number)
                }
                .accessibilityIdentifier("invoice-selection-service-count")
                LabeledContent("Total") {
                    Text(selectionTotal)
                        .fontWeight(.semibold)
                }
                .accessibilityIdentifier("invoice-selection-total")
            }
            if !model.hasValidBusinessProfile {
                Section("Finish Business Setup") {
                    NavigationLink {
                        BusinessProfileEditorView(onSaved: reload)
                    } label: {
                        Label("Set Up My Business", systemImage: "person.text.rectangle")
                    }
                    Text("Add a business or farrier name before generating an invoice.")
                        .foregroundStyle(.secondary)
                }
            }
            if let draft = model.draft {
                Section("Invoice") {
                    DatePicker(
                        "Invoice Date",
                        selection: Binding(
                            get: { model.draft?.invoiceDate ?? draft.invoiceDate },
                            set: { model.updateInvoiceDate($0) }
                        ),
                        displayedComponents: .date
                    )
                    Toggle("Add Due Date", isOn: dueDateEnabled)
                    if model.draft?.dueDate != nil {
                        DatePicker("Due Date", selection: dueDateBinding, displayedComponents: .date)
                    }
                }
                Section("Note") {
                    TextField(
                        "Invoice Note",
                        text: draftBinding(\.note, fallback: draft.note),
                        axis: .vertical
                    )
                        .lineLimit(3...6)
                        .focused($isNoteFocused)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func draftBinding<Value>(
        _ keyPath: WritableKeyPath<InvoiceCreationDraft, Value>,
        fallback: Value
    ) -> Binding<Value> {
        return Binding(
            get: { model.draft?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard var draft = model.draft else { return }
                draft[keyPath: keyPath] = value
                model.draft = draft
            }
        )
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { model.draft?.dueDate != nil },
            set: { model.setDueDateEnabled($0) }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { model.draft?.dueDate ?? model.draft?.invoiceDate ?? .now },
            set: { model.updateDueDate($0) }
        )
    }

    private func generate() {
        guard let invoiceID = model.generate(in: context) else { return }
        onGenerated(invoiceID)
    }

    private var selectionTotal: String {
        guard let total = model.selectionSummary?.totalMinorUnits else {
            return String(localized: "No selection", locale: locale)
        }
        return MoneyFormatter.usd(minorUnits: total, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func reload() {
        model.load(in: context)
    }
}
