import SwiftData
import SwiftUI

struct HorseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
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
                    }
                    if let safetyNotes = horse.safetyNotes {
                        Section("Safety Notes") {
                            Text(safetyNotes)
                                .accessibilityLabel("Safety Notes, \(safetyNotes)")
                        }
                    }
                    historySection
                }
                .navigationTitle(horse.name)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit", systemImage: "pencil") { showsEditor = true }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    HorseEditorView(horse: horse)
                }
                .confirmationDialog(
                    "Delete Horse?",
                    isPresented: $showsDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Horse", role: .destructive) {
                        if model.delete(in: context) { dismiss() }
                    }
                }
            } else {
                ContentUnavailableView("Horse Unavailable", systemImage: "exclamationmark.circle")
            }
        }
        .onAppear(perform: reload)
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        model.load(id: horseID, in: context, locale: locale)
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
    }

    @ViewBuilder
    private var historyRows: some View {
        ForEach(model.history) { entry in
            NavigationLink(value: ClientRoute.visit(entry.visitID)) {
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
