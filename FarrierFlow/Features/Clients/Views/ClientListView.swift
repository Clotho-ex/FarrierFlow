import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var path = NavigationPath()
    @State private var model = ClientListModel()
    @State private var showsEditor = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.clients.isEmpty {
                    ContentUnavailableView {
                        Label("No clients", systemImage: "person.2")
                    } description: {
                        Text("Add a client to begin keeping connected horse records.")
                    } actions: {
                        if subscription.allowsMutations {
                            Button("Add Client", systemImage: "plus") {
                                showsEditor = true
                            }
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(
                                model.clients,
                                id: \.persistentModelID
                            ) { client in
                                RecordNavigationLink(
                                    value: ClientRoute.detail(
                                        client.persistentModelID
                                    )
                                ) {
                                    ClientRow(client: client)
                                }
                                .listRowBackground(ColorTokens.surface)
                            }
                        } header: {
                            Text(clientCountLabel)
                                .textCase(nil)
                        }
                    }
                    .listSectionSpacing(.custom(SpacingTokens.related))
                    .farrierFlowScrollBackground()
                }
            }
            .farrierFlowScreenBackground()
            .navigationTitle("Clients")
            .toolbarTitleDisplayMode(
                dynamicTypeSize.isAccessibilitySize ? .inline : .inlineLarge
            )
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if subscription.allowsMutations {
                        Button("Add Client", systemImage: "plus") {
                            showsEditor = true
                        }
                    }
                    Menu {
                        Section("Business Tools") {
                            Button("Service Locations", systemImage: "mappin.and.ellipse") {
                                path.append(BarnRoute.list)
                            }
                            Button("Services", systemImage: "wrench.and.screwdriver") {
                                path.append(ServiceRoute.list)
                            }
                            Button("Invoices", systemImage: "doc.text") {
                                path.append(InvoiceRoute.list)
                            }
                        }
                        Section("Settings") {
                            Button(
                                "My Business",
                                systemImage: "person.text.rectangle"
                            ) {
                                path.append(BusinessProfileRoute.editor)
                            }
                            Button("Subscription", systemImage: "creditcard") {
                                path.append(SubscriptionRoute.store)
                            }
                            Button {
                                path.append(BackupSyncRoute.account)
                            } label: {
                                Label {
                                    Text(BackupSyncCopy.title)
                                } icon: {
                                    Image(systemName: "icloud")
                                }
                            }
                            .accessibilityIdentifier("backup-sync-open")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .tint(ColorTokens.textSecondary)
                }
            }
            .navigationDestination(for: ClientRoute.self) { route in
                switch route {
                case .detail(let id):
                    ClientDetailView(clientID: id)
                case .horse(let id):
                    HorseDetailView(horseID: id)
                case .visit(let id):
                    VisitDetailView(visitID: id, container: context.container)
                }
            }
            .navigationDestination(for: BarnRoute.self) { route in
                switch route {
                case .list:
                    BarnListView()
                case .detail(let id):
                    BarnDetailView(barnID: id)
                }
            }
            .navigationDestination(for: ServiceRoute.self) { route in
                switch route {
                case .list:
                    ServiceListView()
                case .detail(let id):
                    ServiceDetailView(serviceID: id)
                }
            }
            .navigationDestination(for: BusinessProfileRoute.self) { route in
                switch route {
                case .editor:
                    BusinessProfileEditorView()
                }
            }
            .navigationDestination(for: SubscriptionRoute.self) { route in
                switch route {
                case .store:
                    SubscriptionView(
                        presentation: .standard(
                            showsManageSubscriptionButton: true
                        )
                    )
                }
            }
            .navigationDestination(for: InvoiceRoute.self) { route in
                switch route {
                case .list:
                    InvoiceListView()
                case .history:
                    InvoiceHistoryView(container: context.container)
                case .detail(let id):
                    InvoiceDetailView(invoiceID: id)
                case .create(let clientID):
                    InvoiceCreationView(clientID: clientID) { invoiceID in
                        if path.count > 0 { path.removeLast() }
                        path.append(InvoiceRoute.detail(invoiceID))
                    }
                }
            }
            .navigationDestination(for: BackupSyncRoute.self) { _ in
                BackupSyncView()
            }
            .navigationDestination(for: InvoiceHistoryRoute.self) { route in
                switch route {
                case .list:
                    InvoiceHistoryView(container: context.container)
                case .detail(let identity):
                    InvoiceHistoryDetailView(
                        identity: identity,
                        container: context.container
                    )
                }
            }
            .sheet(isPresented: $showsEditor, onDismiss: reload) {
                ClientEditorView()
            }
            .onAppear(perform: reload)
            .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private func reload() {
        model.load(in: context)
    }

    private var clientCountLabel: LocalizedStringKey {
        model.clients.count == 1
            ? "1 client"
            : "\(model.clients.count) clients"
    }

}

#Preview("Clients — Empty, Accessibility") {
    if let container = try? ModelContainerFactory.inMemoryTest() {
        ClientListView()
            .modelContainer(container)
            .dynamicTypeSize(.accessibility3)
    } else {
        ModelContainerFailureView()
    }
}
