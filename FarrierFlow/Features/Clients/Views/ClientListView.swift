import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.modelContext) private var context
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
                        Button("Add Client", systemImage: "plus") {
                            showsEditor = true
                        }
                    }
                } else {
                    List(model.clients, id: \.persistentModelID) { client in
                        NavigationLink(value: ClientRoute.detail(client.persistentModelID)) {
                            ClientRow(client: client)
                        }
                    }
                }
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Add Client", systemImage: "plus") {
                        showsEditor = true
                    }
                    Menu {
                        Button("Service Locations", systemImage: "building.2") {
                            path.append(BarnRoute.list)
                        }
                        Button("Services", systemImage: "wrench.and.screwdriver") {
                            path.append(ServiceRoute.list)
                        }
                        Button(
                            "Business Profile",
                            systemImage: "person.text.rectangle"
                        ) {
                            path.append(BusinessProfileRoute.editor)
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
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
            .sheet(isPresented: $showsEditor, onDismiss: reload) {
                ClientEditorView()
            }
            .onAppear(perform: reload)
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private func reload() {
        model.load(in: context)
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
