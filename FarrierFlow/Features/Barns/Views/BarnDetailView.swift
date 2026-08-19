import SwiftData
import SwiftUI

struct BarnDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model = BarnDetailModel()
    @State private var showsEditor = false
    @State private var showsHorseEditor = false
    @State private var showsExistingHorsePicker = false
    @State private var showsDeleteConfirmation = false

    let barnID: PersistentIdentifier

    var body: some View {
        Group {
            if let barn = model.barn {
                List {
                    if barn.address != nil || barn.contactNotes != nil {
                        Section("Service Location") {
                            if let address = barn.address {
                                LabeledContent("Address", value: address)
                            }
                            if let contactNotes = barn.contactNotes {
                                LabeledContent("Contact Notes", value: contactNotes)
                            }
                        }
                    }
                    Section("Horses") {
                        ForEach(
                            barn.horses.sorted {
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
                .navigationTitle(barn.name)
                .toolbar {
                    if subscription.allowsMutations {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Add Horse", systemImage: "plus") {
                                showsHorseEditor = true
                            }
                            Button("Add Existing Horse", systemImage: "arrow.right") {
                                showsExistingHorsePicker = true
                            }
                            Divider()
                            Button("Edit", systemImage: "pencil") { showsEditor = true }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                showsDeleteConfirmation = true
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                    }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    BarnEditorView(barn: barn)
                }
                .sheet(isPresented: $showsHorseEditor, onDismiss: reload) {
                    HorseEditorView(preselectedBarnID: barnID)
                }
                .sheet(isPresented: $showsExistingHorsePicker, onDismiss: reload) {
                    ExistingHorsePickerView(destinationBarnID: barnID)
                }
                .confirmationDialog(
                    "Delete Service Location?",
                    isPresented: $showsDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Service Location", role: .destructive) {
                        guard subscription.allowsMutations else { return }
                        if model.delete(in: context) { dismiss() }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Service Location Unavailable",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
        .onAppear(perform: reload)
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: barnID, in: context)
    }
}
