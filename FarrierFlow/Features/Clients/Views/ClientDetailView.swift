import SwiftData
import SwiftUI

struct ClientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
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
                    Section("Horses") {
                        if client.horses.isEmpty {
                            ContentUnavailableView {
                                Label("No Horses", systemImage: "figure.equestrian.sports")
                            } description: {
                                Text("Add this client’s first horse to start scheduling work.")
                            } actions: {
                                Button("Add Horse") {
                                    showsHorseEditor = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            ForEach(
                                client.horses.sorted {
                                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                },
                                id: \.persistentModelID
                            ) { horse in
                                NavigationLink(value: ClientRoute.horse(horse.persistentModelID)) {
                                    HorseRow(horse: horse)
                                }
                            }
                        }
                    }
                    if model.hasInvoiceableWork {
                        Section("Ready to Invoice") {
                            NavigationLink(value: InvoiceRoute.create(clientID)) {
                                Label("Create Invoice", systemImage: "doc.badge.plus")
                            }
                            .accessibilityIdentifier("client-create-invoice-action")
                        }
                    }
                }
                .navigationTitle(client.name)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Add Horse", systemImage: "plus") {
                            showsHorseEditor = true
                        }
                        Menu {
                            Button("Edit", systemImage: "pencil") { showsEditor = true }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                showsDeleteConfirmation = true
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
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
