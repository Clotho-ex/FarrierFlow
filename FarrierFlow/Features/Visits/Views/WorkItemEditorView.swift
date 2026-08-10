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
            initialValue: USDPriceParser.editableString(minorUnits: workItem.amountMinorUnits) ?? ""
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
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Replace Service") {
                        AddServicePickerView(
                            model: model,
                            visitHorseID: visitHorseID,
                            replacingWorkItemID: workItem.id,
                            excludingServiceID: workItem.serviceID,
                            onSuccessfulReplacement: { dismiss() }
                        )
                    }
                    .accessibilityIdentifier("visit-replace-service")
                }

                Section("Amount") {
                    TextField("Price", text: $priceInput)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Price")
                        .accessibilityHint("Enter a U.S. dollar amount with up to two decimal places.")
                        .accessibilityIdentifier("work-item-price-field")
                    Text("Enter a U.S. dollar amount with up to two decimal places.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !priceInput.isEmpty, !model.isValidPriceInput(priceInput) {
                        Text("Enter a valid U.S. dollar amount.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else {
                        Text(currentFormattedAmount)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section {
                    Button("Remove Service", role: .destructive) {
                        showsRemoveConfirmation = true
                    }
                    .accessibilityIdentifier("visit-remove-service")
                }
            }
            .disabled(!subscription.allowsMutations)
            .navigationTitle("Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!subscription.allowsMutations || !model.isValidPriceInput(priceInput))
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

    private var currentFormattedAmount: String {
        MoneyFormatter.usd(minorUnits: workItem.amountMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }

    private func save() {
        guard subscription.allowsMutations else { return }
        guard model.updateWorkItem(
            workItem.id,
            serviceID: workItem.serviceID,
            priceInput: priceInput,
            for: visitHorseID
        ) else {
            showsUpdateError = true
            return
        }
        dismiss()
    }
}
