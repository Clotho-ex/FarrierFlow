import SwiftData
import SwiftUI

struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
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
                    ServiceFormFields(draft: $model.draft)
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
                        if let id = model.save(
                            in: context,
                            analyticsClient: analyticsClient
                        ) {
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

}

struct ServiceFormFields: View {
    private enum Field: Hashable { case name, price }
    @Environment(\.locale) private var locale
    @FocusState private var focusedField: Field?
    @Binding var draft: ServiceDraft

    var body: some View {
        Group {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .price }
                .frame(minHeight: 44)
                .accessibilityIdentifier("service-name-field")
                .toolbar {
                    if focusedField != nil {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { focusedField = nil }
                                .accessibilityIdentifier("service-keyboard-done")
                        }
                    }
                }
            TextField("Default Price", text: $draft.priceInput)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .price)
                .frame(minHeight: 44)
                .accessibilityIdentifier("service-price-field")
            Text("Enter an amount in \(currencyLabel) with up to two decimal places.")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
            priceFeedback
        }
    }

    @ViewBuilder
    private var priceFeedback: some View {
        if let values = try? ServiceRules.validated(draft, locale: locale),
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
        } else if !draft.priceInput.isEmpty {
            Text("Enter a valid amount in \(currencyLabel).")
                .font(.footnote)
                .foregroundStyle(ColorTokens.destructive)
        }
    }

    private var currencyLabel: String {
        guard let currency = BusinessCurrency(rawValue: draft.currencyCode) else {
            return draft.currencyCode
        }
        return "\(currency.localizedName(in: locale)) (\(currency.rawValue))"
    }
}
