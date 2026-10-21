import SwiftData
import SwiftUI

struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var model = ClientDetailModel()
    @State private var showsEditor = false
    @State private var showsHorseEditor = false
    @State private var showsDeleteConfirmation = false

    let clientID: PersistentIdentifier

    var body: some View {
        Group {
            if let client = model.client {
                List {
                    Section {
                        VStack(
                            alignment: .leading,
                            spacing: SpacingTokens.tight
                        ) {
                            Text(client.name)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text("Client profile")
                                .font(Typography.recordMetadata)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let phone = client.phone {
                            LabeledContent("Phone", value: phone)
                        }
                        if let email = client.email {
                            LabeledContent("Email", value: email)
                        }
                        if let notes = client.notes {
                            LabeledContent("Notes", value: notes)
                        }

                        if !hasContactDetails(client),
                           subscription.allowsMutations {
                            Button(
                                "Add Contact Details",
                                systemImage: "person.crop.circle.badge.plus"
                            ) {
                                showsEditor = true
                            }
                        }
                    }
                    .listRowBackground(ColorTokens.surface)

                    Section {
                        if client.horses.isEmpty {
                            Label(
                                "No horses yet",
                                systemImage: "figure.equestrian.sports"
                            )
                            .foregroundStyle(ColorTokens.textSecondary)
                        } else {
                            ForEach(
                                client.horses.sorted {
                                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                },
                                id: \.id
                            ) { horse in
                                RecordNavigationLink(value: ClientRoute.horse(horse.id)) {
                                    HorseRow(
                                        horse: horse,
                                        context: .clientDetail
                                    )
                                }
                            }
                        }
                    } header: {
                        horsesSectionHeader
                        .textCase(nil)
                    }
                    .listRowBackground(ColorTokens.surface)

                    if !model.invoices.isEmpty {
                        Section {
                            ForEach(model.invoices) { invoice in
                                RecordNavigationLink(value: InvoiceRoute.detail(invoice.id)) {
                                    InvoiceRow(
                                        summary: invoice,
                                        showsClientName: false
                                    )
                                }
                                .badge(
                                    dynamicTypeSize.isAccessibilitySize ? nil : Text(invoice.status.displayName)
                                        .foregroundStyle(invoice.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
                                )
                                .accessibilityIdentifier("client-invoice-\(invoice.number)")
                            }
                        } header: {
                            Text("Invoices")
                                .textCase(nil)
                        }
                        .listRowBackground(ColorTokens.surface)
                    }

                    if model.hasInvoiceableWork, subscription.allowsMutations {
                        Section("Ready to Invoice") {
                            RecordNavigationLink(value: InvoiceRoute.create(clientID)) {
                                Label("Create Invoice", systemImage: "doc.badge.plus")
                            }
                            .accessibilityIdentifier("client-create-invoice-action")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                }
                .listSectionSpacing(
                    .custom(SpacingTokens.recordSection)
                )
                .farrierFlowScrollBackground()
                .navigationTitle("Client")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if subscription.allowsMutations {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Edit", systemImage: "pencil") {
                                    showsEditor = true
                                }
                                .tint(ColorTokens.textSecondary)
                                Button(
                                    "Delete",
                                    systemImage: "trash",
                                    role: .destructive
                                ) {
                                    showsDeleteConfirmation = true
                                }
                            } label: {
                                Label(
                                    "Actions",
                                    systemImage: "ellipsis.circle"
                                )
                            }
                            .tint(ColorTokens.textSecondary)
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    ClientEditorDestination(clientID: client.id)
                }
                .sheet(isPresented: $showsHorseEditor, onDismiss: reload) {
                    HorseEditorView(preselectedClientID: clientID)
                }
                .recordDeletionSheet(
                    .client(clientID), isPresented: $showsDeleteConfirmation,
                    title: "Delete Client?", confirmationTitle: "Delete Client",
                    accessibilityPrefix: "client-delete", alert: $model.alert
                ) { dismiss() }
            } else {
                ContentUnavailableView("Client Unavailable", systemImage: "exclamationmark.circle")
            }
        }
        .onAppear(perform: reload)
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: clientID, in: ModelContext(context.container))
    }



    private func hasContactDetails(_ client: ClientDetailSnapshot) -> Bool {
        client.phone != nil || client.email != nil || client.notes != nil
    }

    @ViewBuilder
    private var horsesSectionHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                Text("Horses")
                addHorseButton
            }
        } else {
            HStack(spacing: SpacingTokens.compact) {
                Text("Horses")
                Spacer(minLength: SpacingTokens.compact)
                addHorseButton
            }
        }
    }

    @ViewBuilder
    private var addHorseButton: some View {
        if subscription.allowsMutations {
            Button("Add Horse", systemImage: "plus") {
                showsHorseEditor = true
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: SpacingTokens.minimumTouchTarget)
        }
    }
}

private struct ClientEditorDestination: View {
    @Environment(\.modelContext) private var context

    let clientID: PersistentIdentifier

    var body: some View {
        if let record = try? context.existingModel(Client.self, for: clientID) {
            ClientEditorView(client: record)
        } else {
            ContentUnavailableView(
                "Client Unavailable",
                systemImage: "exclamationmark.circle"
            )
        }
    }
}
