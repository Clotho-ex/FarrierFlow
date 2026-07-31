import SwiftData
import SwiftUI

struct AddServicePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

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
        Group {
            if services.isEmpty {
                ContentUnavailableView {
                    Label("No Services Available", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Add or reactivate a Service before recording work.")
                } actions: {
                    if replacingWorkItemID == nil {
                        Button("Create Service", systemImage: "plus") {
                            showsServiceEditor = true
                        }
                        .accessibilityIdentifier("visit-create-service-action")
                    }
                }
            } else {
                List(services) { service in
                    Button {
                        select(service)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
                            Text(service.name)
                                .font(Typography.recordTitle)
                            Spacer(minLength: SpacingTokens.rowContent)
                            Text(formattedAmount(for: service))
                                .font(Typography.recordMetadata)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityLabel("\(service.name), \(formattedAmount(for: service))")
                    .accessibilityHint(replacingWorkItemID == nil ? "Add Service" : "Replace Service")
                    .accessibilityIdentifier("visit-service-option-\(service.name)")
                }
            }
        }
        .navigationTitle(replacingWorkItemID == nil ? "Add Service" : "Replace Service")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsServiceEditor, onDismiss: addCreatedServiceIfNeeded) {
            ServiceEditorView(createdServiceID: $createdServiceID)
        }
        .alert("Couldn’t Update Work Item", isPresented: $showsSelectionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The Service is still in the visit. Try again.")
        }
    }

    private var services: [ServiceChoice] {
        model.eligibleServices(
            for: visitHorseID,
            replacing: replacingWorkItemID
        )
        .filter { $0.id != excludingServiceID }
    }

    private func formattedAmount(for service: ServiceChoice) -> String {
        MoneyFormatter.usd(
            minorUnits: service.defaultAmountMinorUnits,
            locale: locale
        ) ?? String(localized: "Unavailable", locale: locale)
    }

    private func select(_ service: ServiceChoice) {
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
        guard let createdServiceID else { return }
        self.createdServiceID = nil

        guard model.addService(createdServiceID, to: visitHorseID) else {
            showsSelectionError = true
            return
        }

        dismiss()
    }
}
