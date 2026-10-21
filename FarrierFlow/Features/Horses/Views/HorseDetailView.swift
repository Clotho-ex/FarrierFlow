import SwiftData
import SwiftUI

struct HorseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var model = HorseDetailModel()
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false

    let horseID: PersistentIdentifier

    var body: some View {
        Group {
            if let horse = model.horse {
                List {
                    Section("Horse") {
                        LabeledContent("Name", value: horse.name)
                        LabeledContent(
                            "Client",
                            value: horse.client?.name
                                ?? String(localized: "Unavailable", locale: locale)
                        )
                            .accessibilityIdentifier("horse-detail-client")
                        LabeledContent(
                            "Service Location",
                            value: horse.currentBarn?.name
                                ?? String(localized: "Unavailable", locale: locale)
                        )
                            .accessibilityIdentifier("horse-detail-service-location")
                        LabeledContent("Appointment Interval") {
                            Text(
                                verbatim: AppointmentIntervalFormatter.string(
                                    weeks: horse.appointmentIntervalWeeks,
                                    locale: locale
                                )
                            )
                        }
                        .accessibilityIdentifier(
                            "horse-detail-appointment-interval"
                        )
                        LabeledContent(
                            "Default Service",
                            value: model.defaultService.map {
                                "\($0.name) · \($0.formattedAmount)"
                            } ?? String(localized: "Not Set", locale: locale)
                        )
                        .accessibilityIdentifier("horse-detail-default-service")
                    }
                    .listRowBackground(ColorTokens.surface)
                    if let safetyNotes = horse.safetyNotes {
                        Section("Safety Notes") {
                            Label {
                                Text(safetyNotes)
                                    .foregroundStyle(ColorTokens.textPrimary)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(ColorTokens.warning)
                            }
                                .accessibilityLabel("Safety Notes, \(safetyNotes)")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                    if !model.usage.appointments.isEmpty {
                        Section {
                            ForEach(model.usage.appointments) { appointment in
                                LinkedAppointmentRow(appointment: appointment)
                            }
                        } header: {
                            Text("Appointments")
                        } footer: {
                            Text("Open an appointment to review this horse’s scheduled work.")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                    if !model.inProgressVisits.isEmpty {
                        Section {
                            ForEach(model.inProgressVisits) { visit in
                                LinkedVisitRow(visit: visit)
                            }
                        } header: {
                            Text("In Progress Visits")
                        } footer: {
                            Text("These visits also reference this horse, even though they are not yet in completed history.")
                        }
                        .listRowBackground(ColorTokens.surface)
                    }
                    historySection
                }
                .farrierFlowScrollBackground()
                .navigationTitle(horse.name)
                .toolbar {
                    if subscription.allowsMutations {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit", systemImage: "pencil") { showsEditor = true }
                            .tint(ColorTokens.textSecondary)
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .tint(ColorTokens.destructive)
                    }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    HorseEditorDestination(horseID: horse.id)
                }
                .recordDeletionSheet(
                    .horse(horseID), isPresented: $showsDeleteConfirmation,
                    title: "Delete Horse?", confirmationTitle: "Delete Horse",
                    accessibilityPrefix: "horse-delete", alert: $model.alert
                ) { dismiss() }
            } else {
                ContentUnavailableView("Horse Unavailable", systemImage: "exclamationmark.circle")
            }
        }
        .onAppear(perform: reload)
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }



    private func reload() {
        model.load(id: horseID, in: ModelContext(context.container), locale: locale)
    }

    @ViewBuilder
    private var historySection: some View {
        Section("History") {
            switch model.historyLoadState {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Loading History…")
                }
            case .loaded:
                if model.history.isEmpty {
                    ContentUnavailableView(
                        "No Completed Visits",
                        systemImage: "clock",
                        description: Text("Completed work will appear here after a visit is completed.")
                    )
                } else {
                    historyRows
                }
            case .failed:
                if !model.history.isEmpty {
                    historyRows
                }
                ContentUnavailableView {
                    Label("History Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("Horse history couldn’t be loaded.")
                } actions: {
                    Button("Retry") {
                        model.retryHistory()
                    }
                }
            }
        }
        .listRowBackground(ColorTokens.surface)
    }

    @ViewBuilder
    private var historyRows: some View {
        ForEach(model.history) { entry in
            RecordNavigationLink(value: ClientRoute.visit(entry.visitID)) {
                HorseHistoryRow(entry: entry)
            }
            .accessibilityIdentifier("horse-history-visit-\(entry.horseName)")
        }
    }
}

private struct HorseHistoryPreview: View {
    private let fixture: PreviewFixtures.HorseHistoryPreviewFixture?

    init(populated: Bool) {
        fixture = try? PreviewFixtures.horseHistoryPreview(populated: populated)
    }

    var body: some View {
        if let fixture {
            HorseDetailView(horseID: fixture.horseID)
                .modelContainer(fixture.container)
        } else {
            ModelContainerFailureView()
        }
    }
}

#Preview("Horse History — Populated") {
    HorseHistoryPreview(populated: true)
}

#Preview("Horse History — Empty, Accessibility") {
    HorseHistoryPreview(populated: false)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}

private struct HorseEditorDestination: View {
    @Environment(\.modelContext) private var context

    let horseID: PersistentIdentifier

    var body: some View {
        if let record = try? context.existingModel(Horse.self, for: horseID) {
            HorseEditorView(horse: record)
        } else {
            ContentUnavailableView(
                "Horse Unavailable",
                systemImage: "exclamationmark.circle"
            )
        }
    }
}
