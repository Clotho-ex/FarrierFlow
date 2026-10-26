import SwiftData
import SwiftUI

struct AddServicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SubscriptionAccessModel.self) private var subscription

    @Bindable var model: VisitEditorModel
    let visitHorseID: PersistentIdentifier
    let replacingWorkItemID: UUID?
    let excludingServiceID: PersistentIdentifier?
    let onSuccessfulReplacement: (() -> Void)?

    @State private var showsSelectionError = false
    @State private var showsServiceEditor = false
    @State private var createdServiceID: PersistentIdentifier?

    init(
        model: VisitEditorModel,
        visitHorseID: PersistentIdentifier,
        replacingWorkItemID: UUID? = nil,
        excludingServiceID: PersistentIdentifier? = nil,
        onSuccessfulReplacement: (() -> Void)? = nil
    ) {
        self.model = model
        self.visitHorseID = visitHorseID
        self.replacingWorkItemID = replacingWorkItemID
        self.excludingServiceID = excludingServiceID
        self.onSuccessfulReplacement = onSuccessfulReplacement
    }

    var body: some View {
        let choices = services
        List {
            Section {
                if choices.isEmpty {
                    Text("No Services Available")
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                ForEach(choices) { service in
                    Button {
                        select(service)
                    } label: {
                        serviceRowLayout {
                            Text(service.name)
                                .font(Typography.recordTitle)
                            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: SpacingTokens.rowContent) }
                            Text(formattedAmount(for: service))
                                .font(Typography.recordMetadata)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .monospacedDigit()
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .disabled(!subscription.allowsMutations)
                    .accessibilityLabel("\(service.name), \(formattedAmount(for: service))")
                    .accessibilityHint(replacingWorkItemID == nil ? "Add Service" : "Replace Service")
                    .accessibilityIdentifier("visit-service-option-\(service.name)")
                    .listRowBackground(ColorTokens.surface)
                }
            }
            .listRowBackground(ColorTokens.surface)
            if subscription.allowsMutations {
                Section {
                    Button("Create New Service", systemImage: "plus") { showsServiceEditor = true }
                        .accessibilityIdentifier("visit-create-service-action")
                }
                .listRowBackground(ColorTokens.surface)
            }
        }
        .farrierFlowScrollBackground()
        .navigationTitle(replacingWorkItemID == nil ? "Add Service" : "Replace Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if replacingWorkItemID == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showsServiceEditor, onDismiss: addCreatedServiceIfNeeded) {
            ServiceEditorView(createdServiceID: $createdServiceID)
        }
        .alert("Couldn’t Update Work Item", isPresented: $showsSelectionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The Service is still in the visit. Try again.")
        }
    }

    private var serviceRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.rowContent))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent))
    }

    private var services: [ServiceChoice] {
        model.eligibleServices(
            for: visitHorseID,
            replacing: replacingWorkItemID
        )
        .filter { $0.id != excludingServiceID }
    }

    private func formattedAmount(for service: ServiceChoice) -> String {
        MoneyFormatter.currency(
            minorUnits: service.defaultAmountMinorUnits,
            currencyCode: service.currencyCode,
            locale: locale
        ) ?? String(localized: "Unavailable", locale: locale)
    }

    private func select(_ service: ServiceChoice) {
        guard subscription.allowsMutations else { return }
        let succeeded: Bool
        if let replacingWorkItemID {
            succeeded = model.replaceWorkItem(
                replacingWorkItemID,
                with: service.id,
                for: visitHorseID
            )
        } else {
            succeeded = model.addService(service.id, to: visitHorseID)
        }

        guard succeeded else {
            showsSelectionError = true
            return
        }

        if let onSuccessfulReplacement {
            onSuccessfulReplacement()
        } else {
            dismiss()
        }
    }

    private func addCreatedServiceIfNeeded() {
        guard subscription.allowsMutations else { return }
        guard let createdServiceID else { return }
        self.createdServiceID = nil

        let succeeded: Bool
        if let replacingWorkItemID {
            succeeded = model.replaceWorkItem(replacingWorkItemID, with: createdServiceID, for: visitHorseID)
        } else {
            succeeded = model.addService(createdServiceID, to: visitHorseID)
        }
        guard succeeded else {
            showsSelectionError = true
            return
        }

        if let onSuccessfulReplacement { onSuccessfulReplacement() }
        else { dismiss() }
    }
}
