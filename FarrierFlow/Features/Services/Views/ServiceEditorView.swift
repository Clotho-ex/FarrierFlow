import SwiftData
import SwiftUI

struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: ServiceEditorModel
    @State private var dismissalBaseline: ServiceDraft?
    @State private var inputID = UUID()
    @FocusState private var focusedField: ServiceFormFields.Field?
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
                RecordSection(Text("Service")) {
                    ServiceFormFields(draft: $model.draft, inputID: inputID, focusedField: $focusedField)
                }
                .listRowBackground(ColorTokens.surface)
            }
            .farrierFlowScrollBackground()
            .scrollDismissesKeyboard(.interactively)
            .disabled(!subscription.allowsMutations)
            .navigationTitle(model.serviceID == nil ? "New Service" : "Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneAccessory(isFocused: focusedField != nil, identifier: "service-keyboard-done") { focusedField = nil }
            .keepFocusedInputVisible(focusedField)
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
                if dismissalBaseline == nil { dismissalBaseline = model.draft }
            }
        }
        .interactiveDismissDisabled(dismissalBaseline.map { $0 != model.draft } ?? false)
    }

}

struct ServiceFormFields: View {
    enum Field: Hashable { case name(UUID), price(UUID) }
    @Environment(\.locale) private var locale
    @Binding var draft: ServiceDraft
    let inputID: UUID
    @FocusState.Binding var focusedField: Field?

    var body: some View {
        Group {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name(inputID))
                .submitLabel(.next)
                .onSubmit { focusedField = .price(inputID) }
                .frame(minHeight: 44)
                .accessibilityIdentifier("service-name-field")
                .inputLimit($draft.name, maximum: InputLimits.name)
                .focusedInputAnchor(Field.name(inputID))
            TextField("Default Price", text: $draft.priceInput)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .price(inputID))
                .frame(minHeight: 44)
                .accessibilityIdentifier("service-price-field")
                .inputLimit($draft.priceInput, maximum: InputLimits.price, rejectOverflow: true)
                .focusedInputAnchor(Field.price(inputID))
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
                .rollingStateText(value: formatted)
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
