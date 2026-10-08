import SwiftData
import SwiftUI

struct WorkItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(SubscriptionAccessModel.self) private var subscription

    @Bindable var model: VisitEditorModel
    let visitHorseID: PersistentIdentifier
    let workItem: WorkItemDraft

    @State private var priceInput: String
    @State private var showsRemoveConfirmation = false
    @State private var showsUpdateError = false

    init(
        model: VisitEditorModel,
        visitHorseID: PersistentIdentifier,
        workItem: WorkItemDraft
    ) {
        self.model = model
        self.visitHorseID = visitHorseID
        self.workItem = workItem
        _priceInput = State(
            initialValue: MoneyInputParser.editableString(
                minorUnits: workItem.amountMinorUnits,
                locale: .current
            ) ?? ""
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    LabeledContent("Service", value: workItem.serviceNameSnapshot)
                    if workItem.serviceIsArchived {
                        Text("Archived")
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    RecordNavigationLink {
                        AddServicePickerView(
                            model: model,
                            visitHorseID: visitHorseID,
                            replacingWorkItemID: workItem.id,
                            excludingServiceID: workItem.serviceID,
                            onSuccessfulReplacement: { dismiss() }
                        )
                    } label: {
                        Text("Replace Service")
                    }
                    .accessibilityIdentifier("visit-replace-service")
                }
                .listRowBackground(ColorTokens.surface)

                Section("Amount") {
                    TextField("Price", text: $priceInput)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Price")
                        .accessibilityHint("Enter an amount in \(currencyLabel) with up to two decimal places.")
                        .accessibilityIdentifier("work-item-price-field")
                    Text("Enter an amount in \(currencyLabel) with up to two decimal places.")
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                    if !priceInput.isEmpty, !model.isValidPriceInput(
                        priceInput,
                        currencyCode: workItem.currencyCode,
                        locale: locale
                    ) {
                        Text("Enter a valid amount in \(currencyLabel).")
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.destructive)
                    } else {
                        Text(currentFormattedAmount)
                            .font(.footnote)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .monospacedDigit()
                    }
                }
                .listRowBackground(ColorTokens.surface)

                Section {
                    Button("Remove Service", role: .destructive) {
                        showsRemoveConfirmation = true
                    }
                    .foregroundStyle(ColorTokens.destructive)
                    .accessibilityIdentifier("visit-remove-service")
                }
                .listRowBackground(ColorTokens.surface)
            }
            .farrierFlowScrollBackground()
            .disabled(!subscription.allowsMutations)
            .navigationTitle("Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(
                        !subscription.allowsMutations
                            || !model.isValidPriceInput(
                                priceInput,
                                currencyCode: workItem.currencyCode,
                                locale: locale
                            )
                    )
                }
            }
        }
        .confirmationDialog(
            "Remove Service?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Service", role: .destructive) {
                guard subscription.allowsMutations else { return }
                if model.removeWorkItem(workItem.id, from: visitHorseID) {
                    dismiss()
                } else {
                    showsUpdateError = true
                }
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("This removes the Service from this horse’s visit. The reusable Service is kept.")
        }
        .alert("Couldn’t Update Work Item", isPresented: $showsUpdateError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The Service is still in the visit. Try again.")
        }
    }

    private var currencyLabel: String {
        guard let currency = BusinessCurrency(rawValue: workItem.currencyCode) else {
            return workItem.currencyCode
        }
        return "\(currency.localizedName(in: locale)) (\(currency.rawValue))"
    }

    private var currentFormattedAmount: String {
        MoneyFormatter.currency(
            minorUnits: workItem.amountMinorUnits,
            currencyCode: workItem.currencyCode,
            locale: locale
        )
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func save() {
        guard subscription.allowsMutations else { return }
        guard model.updateWorkItem(
            workItem.id,
            serviceID: workItem.serviceID,
            priceInput: priceInput,
            for: visitHorseID,
            locale: locale
        ) else {
            showsUpdateError = true
            return
        }
        dismiss()
    }
}
