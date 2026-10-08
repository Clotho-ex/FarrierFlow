import SwiftData
import SwiftUI

struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
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
                    Text("Enter an amount in \(currencyLabel) with up to two decimal places.")
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                    priceFeedback
                }
                .listRowBackground(ColorTokens.surface)
            }
            .farrierFlowScrollBackground()
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.serviceID == nil ? "New Service" : "Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard subscription.allowsMutations else { return }
                        if let id = model.save(in: context) {
                            createdServiceID?.wrappedValue = id
                            dismiss()
                        }
                    }
                    .disabled(!subscription.allowsMutations || !model.canSave)
                }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
            .task {
                model.loadBusinessCurrency(in: context)
            }
        }
    }

    @ViewBuilder
    private var priceFeedback: some View {
        if let values = try? ServiceRules.validated(model.draft, locale: locale),
           let formatted = MoneyFormatter.currency(
               minorUnits: values.defaultAmountMinorUnits,
               currencyCode: values.currencyCode,
               locale: locale
           ) {
            Text(formatted)
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityLabel(
                    String(localized: "Default price \(formatted)", locale: locale)
                )
        } else if !model.draft.priceInput.isEmpty {
            Text("Enter a valid amount in \(currencyLabel).")
                .font(.footnote)
                .foregroundStyle(ColorTokens.destructive)
        }
    }

    private var currencyLabel: String {
        guard let currency = BusinessCurrency(rawValue: model.draft.currencyCode) else {
            return model.draft.currencyCode
        }
        return "\(currency.localizedName(in: locale)) (\(currency.rawValue))"
    }
}
