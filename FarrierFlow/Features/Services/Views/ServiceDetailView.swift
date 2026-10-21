import SwiftData
import SwiftUI

struct ServiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
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
                    .listRowBackground(ColorTokens.surface)
                    if !service.horsesUsingAsDefault.isEmpty {
                        Section("Horse Defaults") {
                            ForEach(
                                service.horsesUsingAsDefault.sorted {
                                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                                },
                                id: \.id
                            ) { horse in
                                RecordNavigationLink(value: ClientRoute.horse(horse.id)) {
                                    HorseRow(horse: horse)
                                }
                            }
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                    if !model.usage.appointments.isEmpty {
                        Section("Appointments") {
                            ForEach(model.usage.appointments) { appointment in
                                LinkedAppointmentRow(appointment: appointment)
                            }
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                    if !model.usage.visits.isEmpty {
                        Section {
                            ForEach(model.usage.visits) { visit in
                                LinkedVisitRow(visit: visit)
                            }
                        } header: {
                            Text("Recorded Work")
                        } footer: {
                            Text("Open a visit to review its work and invoices. Deleting this service removes its recorded work; saved invoices are kept.")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                }
                .farrierFlowScrollBackground()
                .navigationTitle(service.name)
                .toolbar {
                    if subscription.allowsMutations {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit", systemImage: "pencil") { showsEditor = true }
                                .tint(ColorTokens.textSecondary)
                            if service.isArchived {
                                Button("Reactivate", systemImage: "arrow.counterclockwise") {
                                    guard subscription.allowsMutations else { return }
                                    _ = model.reactivate(in: ModelContext(context.container))
                                }
                            } else {
                                Button("Archive", systemImage: "archivebox") {
                                    guard subscription.allowsMutations else { return }
                                    _ = model.archive(in: ModelContext(context.container))
                                }
                            }
                            Divider()
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
                    ServiceEditorDestination(serviceID: service.id)
                }
                .recordDeletionSheet(
                    .service(serviceID), isPresented: $showsDeleteConfirmation,
                    title: "Delete Service?", confirmationTitle: "Delete Service",
                    accessibilityPrefix: "service-delete", alert: $model.alert
                ) { dismiss() }
            } else {
                ContentUnavailableView("Service Unavailable", systemImage: "exclamationmark.circle")
            }
        }
        .onAppear(perform: reload)
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: serviceID, in: ModelContext(context.container))
    }



    private func formattedAmount(for service: ServiceDetailSnapshot) -> String {
        MoneyFormatter.currency(
            minorUnits: service.defaultAmountMinorUnits,
            currencyCode: service.currencyCode,
            locale: locale
        ) ?? String(localized: "Unavailable", locale: locale)
    }
}

private struct ServiceEditorDestination: View {
    @Environment(\.modelContext) private var context

    let serviceID: PersistentIdentifier

    var body: some View {
        if let record = try? context.existingModel(Service.self, for: serviceID) {
            ServiceEditorView(service: record)
        } else {
            ContentUnavailableView(
                "Service Unavailable",
                systemImage: "exclamationmark.circle"
            )
        }
    }
}
