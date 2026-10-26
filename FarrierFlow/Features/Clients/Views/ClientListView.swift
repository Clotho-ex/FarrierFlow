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
    @State private var searchText = ""

    var body: some View {
        let matchingClients = model.clients.filter { $0.matchesSearch(searchText) }
        NavigationStack(path: $path) {
            Group {
                if model.clients.isEmpty, model.loadState == .loading {
                    ProgressView("Loading clients…")
                } else if model.clients.isEmpty, model.loadState == .failed {
                    ContentUnavailableView {
                        Label("Couldn’t Load Clients", systemImage: "exclamationmark.circle")
                    } description: {
                        Text("FarrierFlow couldn’t load your clients.")
                    } actions: {
                        Button("Retry", action: reload)
                    }
                } else if model.clients.isEmpty {
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
                } else if matchingClients.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        Section {
                            ForEach(
                                matchingClients,
                                id: \.id
                            ) { client in
                                ClientRow(client: client)
                                .listRowBackground(ColorTokens.surface)
                            }
                        } header: {
                            Text(clientCountLabel(matchingClients.count))
                                .recordSectionHeading()
                        }
                    }
                    .listSectionSpacing(.custom(SpacingTokens.related))
                    .farrierFlowScrollBackground()
                }
            }
            .farrierFlowScreenBackground()
            .navigationTitle("Clients")
            .searchable(text: $searchText, prompt: "Name, phone, or horse")
            .toolbarTitleDisplayMode(
                dynamicTypeSize.isAccessibilitySize ? .inline : .inlineLarge
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if subscription.allowsMutations {
                        Button("Add Client", systemImage: "plus") {
                            showsEditor = true
                        }
                        .disabled(model.loadState != .loaded && model.clients.isEmpty)
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
                Alert(title: Text($0.title), message: Text($0.message),
                    primaryButton: .default(Text("Retry"), action: reload), secondaryButton: .cancel())
            }
        }
    }

    private func reload() {
        model.load(in: ModelContext(context.container))
    }

    private func clientCountLabel(_ count: Int) -> LocalizedStringKey {
        count == 1
            ? "1 client"
            : "\(count) clients"
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
