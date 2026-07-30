import SwiftData
import SwiftUI

struct ServiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model = ServiceDetailModel()
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false

    let serviceID: PersistentIdentifier

    var body: some View {
        Group {
            if let service = model.service {
                List {
                    Section("Service") {
                        LabeledContent("Name", value: service.name)
                        LabeledContent("Default Price", value: formattedAmount(for: service))
                        LabeledContent("Status", value: service.isArchived ? "Archived" : "Active")
                    }
                    if !service.horsesUsingAsDefault.isEmpty {
                        Section("Horse Defaults") {
                            ForEach(
                                service.horsesUsingAsDefault.sorted {
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
                }
                .navigationTitle(service.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit", systemImage: "pencil") { showsEditor = true }
                            if service.isArchived {
                                Button("Reactivate", systemImage: "arrow.counterclockwise") {
                                    _ = model.reactivate(in: context)
                                }
                            } else {
                                Button("Archive", systemImage: "archivebox") {
                                    _ = model.archive(in: context)
                                }
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                showsDeleteConfirmation = true
                            }
                        } label: {
                            Label("Actions", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    ServiceEditorView(service: service)
                }
                .confirmationDialog(
                    "Delete Service?",
                    isPresented: $showsDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Service", role: .destructive) {
                        if model.delete(in: context) {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("service-delete-confirmation")
                } message: {
                    Text("This permanently deletes the service when it is not used by a Horse default or recorded work.")
                }
            } else {
                ContentUnavailableView("Service Unavailable", systemImage: "exclamationmark.circle")
            }
        }
        .onAppear(perform: reload)
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: serviceID, in: context)
    }

    private func formattedAmount(for service: Service) -> String {
        MoneyFormatter.usd(
            minorUnits: service.defaultAmountMinorUnits,
            locale: locale
        ) ?? String(localized: "Unavailable", locale: locale)
    }
}
