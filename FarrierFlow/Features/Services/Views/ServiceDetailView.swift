import SwiftData
import SwiftUI

struct ServiceDetailView: View {
    private enum History: Hashable { case appointments, recordedWork }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @Environment(PhotographLibrary.self) private var photographLibrary
    @State private var deletion = RecordDeletionController()
    @State private var model = ServiceDetailModel()
    @State private var showsEditor = false
    @State private var history = History.appointments
    @State private var showsDeleteConfirmation = false

    let serviceID: PersistentIdentifier

    var body: some View {
        Group {
            if let service = model.service {
                List {
                    RecordSection(Text("Service")) {
                        LabeledContent("Name", value: service.name)
                        LabeledContent("Default Price", value: formattedAmount(for: service))
                    }
                    .listRowBackground(ColorTokens.surface)
                    if !service.horsesUsingAsDefault.isEmpty {
                        RecordSection(Text("Horse Defaults")) {
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
                    Section {
                        Picker("Service History", selection: $history) {
                            Text("Appointments").tag(History.appointments)
                            Text("Recorded Work").tag(History.recordedWork)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("service-history-tabs")
                    }
                    .listRowBackground(ColorTokens.background)
                    .listRowInsets(.init())

                    if history == .appointments {
                        RecordSection(Text("Appointments")) {
                            if model.usage.appointments.isEmpty {
                                Text("No appointments use this service.")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            ForEach(model.usage.appointments) { appointment in
                                LinkedAppointmentRow(appointment: appointment)
                            }
                        }
                        .listRowBackground(ColorTokens.surface)
                    } else {
                        RecordSection(Text("Recorded Work")) {
                            if model.usage.visits.isEmpty {
                                Text("No recorded work uses this service.")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                            ForEach(model.usage.visits) { visit in
                                LinkedVisitRow(visit: visit)
                            }
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                    if subscription.allowsMutations {
                        Section {
                            Button(role: .destructive) {
                                deletion.prepare(.service(serviceID), in: context.container)
                                if deletion.impact != nil { showsDeleteConfirmation = true }
                                else { model.alert = deletion.alert }
                            } label: {
                                Text("Delete Service")
                                    .frame(maxWidth: .infinity)
                            }
                            .foregroundStyle(ColorTokens.destructive)
                            .accessibilityIdentifier("service-delete-action")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                }
                .farrierFlowScrollBackground()
                .navigationTitle(service.name)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    if subscription.allowsMutations {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button("Edit Service", systemImage: "pencil") { showsEditor = true }
                                .tint(ColorTokens.textSecondary)
                                .accessibilityIdentifier("service-edit-action")
                            if service.isArchived {
                                Button("Reactivate Service", systemImage: "arrow.counterclockwise") {
                                    guard subscription.allowsMutations else { return }
                                    _ = model.reactivate(in: ModelContext(context.container))
                                }
                                .accessibilityIdentifier("service-reactivate-action")
                                .tint(ColorTokens.textSecondary)
                            } else {
                                Button("Archive Service", systemImage: "archivebox") {
                                    guard subscription.allowsMutations else { return }
                                    if model.archive(in: ModelContext(context.container)) { dismiss() }
                                }
                                .accessibilityIdentifier("service-archive-action")
                                .tint(ColorTokens.textSecondary)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    ServiceEditorDestination(serviceID: service.id)
                }
                .disabled(deletion.isDeleting)
                .alert("Delete Service?", isPresented: $showsDeleteConfirmation,
                       presenting: deletion.impact) { impact in
                    Button("Delete Service", role: .destructive) {
                        guard subscription.allowsMutations else { return }
                        Task {
                            if await deletion.delete(impact, using: photographLibrary) { dismiss() }
                            else { model.alert = deletion.alert }
                        }
                    }
                    .accessibilityIdentifier("service-delete-confirmation")
                    Button("Cancel", role: .cancel) {}
                } message: { impact in
                    Text(impact.warning)
                }
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
