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
        onGenerated: @escaping (PersistentIdentifier) -> Void
    ) {
        self.clientID = clientID
        self.onGenerated = onGenerated
        _model = State(initialValue: InvoiceCreationModel(clientID: clientID))
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
                ForEach(model.visitChoices) { choice in
                    InvoiceVisitSelectionRow(
                        choice: choice,
                        isSelected: model.draft?.selectedVisitIDs.contains(choice.id) == true
                    ) {
                        model.toggleVisit(choice.id)
                    }
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
            if !model.hasValidBusinessProfile {
                Section("Business Profile Required") {
                    NavigationLink {
                        BusinessProfileEditorView(onSaved: reload)
                    } label: {
                        Label("Add Business Profile", systemImage: "person.text.rectangle")
                    }
                    Text("Add a business or farrier name before generating an invoice.")
                        .foregroundStyle(.secondary)
                }
            }
            if let draftBinding = draftBinding {
                Section("Invoice") {
                    DatePicker("Invoice Date", selection: draftBinding.invoiceDate, displayedComponents: .date)
                    Toggle("Add Due Date", isOn: dueDateEnabled)
                    if model.draft?.dueDate != nil {
                        DatePicker("Due Date", selection: dueDateBinding, displayedComponents: .date)
                    }
                }
                Section("Note") {
                    TextField("Invoice Note", text: draftBinding.note, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isNoteFocused)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var draftBinding: Binding<InvoiceCreationDraft>? {
        guard model.draft != nil else { return nil }
        return Binding(
            get: { model.draft! },
            set: { model.draft = $0 }
        )
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { model.draft?.dueDate != nil },
            set: { enabled in
                guard var draft = model.draft else { return }
                draft.dueDate = enabled
                    ? (try? InvoiceDateRules.defaultDueDate(for: draft.invoiceDate, calendar: .current))
                    : nil
                model.draft = draft
            }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { model.draft?.dueDate ?? model.draft?.invoiceDate ?? .now },
            set: { value in
                guard var draft = model.draft else { return }
                draft.dueDate = value
                model.draft = draft
            }
        )
    }

    private func generate() {
        guard let invoiceID = model.generate(in: context) else { return }
        onGenerated(invoiceID)
    }

    private func reload() {
        model.load(in: context)
    }
}
