import SwiftData
import SwiftUI

struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model: ServiceEditorModel
    private let createdServiceID: Binding<PersistentIdentifier?>?

    init(
        service: Service? = nil,
        createdServiceID: Binding<PersistentIdentifier?>? = nil
    ) {
        _model = State(initialValue: ServiceEditorModel(service: service))
        self.createdServiceID = createdServiceID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("Name", text: $model.draft.name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("service-name-field")
                    TextField("Default Price", text: $model.draft.priceInput)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("service-price-field")
                    Text("Enter a U.S. dollar amount with up to two decimal places.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    priceFeedback
                }
            }
            .navigationTitle(model.serviceID == nil ? "New Service" : "Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let id = model.save(in: context) {
                            createdServiceID?.wrappedValue = id
                            dismiss()
                        }
                    }
                    .disabled(!model.canSave)
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    @ViewBuilder
    private var priceFeedback: some View {
        if let values = try? ServiceRules.validated(model.draft),
           let formatted = MoneyFormatter.usd(
               minorUnits: values.defaultAmountMinorUnits,
               locale: locale
           ) {
            Text(formatted)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    String(localized: "Default price \(formatted)", locale: locale)
                )
        } else if !model.draft.priceInput.isEmpty {
            Text("Enter a valid U.S. dollar amount.")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }
}
