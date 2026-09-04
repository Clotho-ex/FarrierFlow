import SwiftData
import SwiftUI

struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model = ClientDetailModel()
    @State private var showsEditor = false
    @State private var showsHorseEditor = false
    @State private var showsDeleteConfirmation = false

    let clientID: PersistentIdentifier

    var body: some View {
        Group {
            if let client = model.client {
                List {
                    Section("Client") {
                        if let phone = client.phone {
                            LabeledContent("Phone", value: phone)
                        }
                        if let email = client.email {
                            LabeledContent("Email", value: email)
                        }
                        if let notes = client.notes {
                            LabeledContent("Notes", value: notes)
                        }
                    }
                    .listRowBackground(ColorTokens.surface)
                    Section("Horses") {
                        if client.horses.isEmpty {
                            ContentUnavailableView {
                                Label("No Horses", systemImage: "figure.equestrian.sports")
                            } description: {
                                Text("Add this client’s first horse to start scheduling work.")
                            } actions: {
                                if subscription.allowsMutations {
                                Button("Add Horse") {
                                    showsHorseEditor = true
                                }
                                .farrierFlowPrimaryAction()
                                }
                            }
                        } else {
                            ForEach(
                                client.horses.sorted {
                                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                },
                                id: \.persistentModelID
                            ) { horse in
                                RecordNavigationLink(value: ClientRoute.horse(horse.persistentModelID)) {
                                    HorseRow(horse: horse)
                                }
                            }
                        }
                    }
                    .listRowBackground(ColorTokens.surface)
                    if !model.invoices.isEmpty {
                        Section("Invoices") {
                            ForEach(model.invoices) { invoice in
                                RecordNavigationLink(value: InvoiceRoute.detail(invoice.id)) {
                                    VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                                        Text("Invoice \(invoice.number)")
                                            .font(Typography.recordTitle)
                                        Text(invoice.invoiceDate, format: .dateTime.month().day().year())
                                            .font(Typography.recordMetadata)
                                            .foregroundStyle(ColorTokens.textSecondary)
                                        if dynamicTypeSize.isAccessibilitySize {
                                            Text(invoice.status.displayName)
                                                .font(Typography.recordMetadata)
                                                .foregroundStyle(invoice.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
                                        }
                                    }
                                }
                                .badge(
                                    dynamicTypeSize.isAccessibilitySize ? nil : Text(invoice.status.displayName)
                                        .foregroundStyle(invoice.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
                                )
                                .accessibilityIdentifier("client-invoice-\(invoice.number)")
                            }
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
                .farrierFlowScrollBackground()
                .navigationTitle(client.name)
                .toolbar {
                    if subscription.allowsMutations {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Add Horse", systemImage: "plus") {
                            showsHorseEditor = true
                        }
                        Menu {
                            Button("Edit", systemImage: "pencil") { showsEditor = true }
                                .tint(ColorTokens.textSecondary)
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                showsDeleteConfirmation = true
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                        .tint(ColorTokens.textSecondary)
                    }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    ClientEditorView(client: client)
                }
                .sheet(isPresented: $showsHorseEditor, onDismiss: reload) {
                    HorseEditorView(preselectedClientID: clientID)
                }
                .confirmationDialog(
                    "Delete Client?",
                    isPresented: $showsDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Client", role: .destructive) {
                        guard subscription.allowsMutations else { return }
                        if model.delete(in: context) { dismiss() }
                    }
                }
            } else {
                ContentUnavailableView("Client Unavailable", systemImage: "exclamationmark.circle")
            }
        }
        .onAppear(perform: reload)
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: clientID, in: context)
    }
}
