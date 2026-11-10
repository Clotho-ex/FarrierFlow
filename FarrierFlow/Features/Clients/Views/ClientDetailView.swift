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
                        Text(client.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("client-identity-name")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: SpacingTokens.compact, leading: SpacingTokens.standard,
                        bottom: SpacingTokens.related, trailing: SpacingTokens.standard
                    ))

                    if hasContactDetails(client) || subscription.allowsMutations {
                        Section {
                            if let phone = client.phone {
                                contactLabel("Phone", value: PhoneNumberFormatting.display(phone))
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("client-phone-information")
                            }
                            if let email = client.email {
                                contactLabel("Email", value: email)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("client-email-information")
                            }
                            if let notes = client.notes {
                                RecordDetailField("Notes") {
                                    Text(verbatim: notes)
                                        .lineSpacing(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(SpacingTokens.related)
                                        .background(ColorTokens.noteSurface, in: .rect(cornerRadius: SpacingTokens.related))
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("client-notes")
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
                        } header: {
                            Text("Contact").recordSectionHeading()
                                .textCase(nil)
                        }
                        .listRowInsets(EdgeInsets(
                            top: SpacingTokens.standard,
                            leading: SpacingTokens.standard,
                            bottom: SpacingTokens.standard,
                            trailing: SpacingTokens.standard
                        ))
                        .listRowBackground(ColorTokens.surface)
                    }

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
                            Text("Invoices").recordSectionHeading()
                                .textCase(nil)
                        }
                        .listRowBackground(ColorTokens.surface)
                    }

                    if model.hasInvoiceableWork, subscription.allowsMutations {
                        RecordSection(Text("Ready to Invoice")) {
                            RecordNavigationLink(value: InvoiceRoute.create(clientID)) {
                                Label("Create Invoice", systemImage: "doc.badge.plus")
                            }
                            .accessibilityIdentifier("client-create-invoice-action")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                }
                // Native section headers already provide the separation here.
                .listSectionSpacing(.custom(0))
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
                .recordDeletionConfirmation(
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

    private func contactLabel(
        _ title: LocalizedStringKey,
        value: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedContactLabel(title, value: value)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(title)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .fixedSize()
                        Spacer(minLength: SpacingTokens.standard)
                        Text(verbatim: value)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .fixedSize()
                    }
                    stackedContactLabel(title, value: value)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: SpacingTokens.minimumTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func stackedContactLabel(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tight) {
            Text(title)
                .foregroundStyle(ColorTokens.textPrimary)
            Text(verbatim: value)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hasContactDetails(_ client: ClientDetailSnapshot) -> Bool {
        client.phone != nil || client.email != nil || client.notes != nil
    }

    @ViewBuilder
    private var horsesSectionHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                Text("Horses").recordSectionHeading()
                addHorseButton
            }
        } else {
            HStack(spacing: SpacingTokens.compact) {
                Text("Horses").recordSectionHeading()
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
