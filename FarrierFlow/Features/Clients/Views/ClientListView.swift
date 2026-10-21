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
                                id: \.id
                            ) { client in
                                RecordNavigationLink(
                                    value: ClientRoute.detail(
                                        client.id
                                    )
                                ) {
                                    ClientRow(client: client)
                                }
                                .listRowBackground(ColorTokens.surface)
                            }
                        } header: {
                            Text(clientCountLabel)
                                .font(Typography.recordMetadata)
                                .foregroundStyle(ColorTokens.textSecondary)
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
                ToolbarItem(placement: .topBarTrailing) {
                    if subscription.allowsMutations {
                        Button("Add Client", systemImage: "plus") {
                            showsEditor = true
                        }
                    }
                }
            }
            .recordNavigationDestinations(path: $path)
            .sheet(isPresented: $showsEditor, onDismiss: reload) {
                ClientEditorView()
            }
            .onAppear(perform: reload)
            .onReceive(ModelSaveChanges.publisher(in: context.container, entities: ["Client", "Horse"])) {
                reload()
            }
            .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private func reload() {
        model.load(in: ModelContext(context.container))
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
