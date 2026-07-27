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
                            Text("\(horse.appointmentIntervalWeeks) weeks")
                        }
                    }
                    if let safetyNotes = horse.safetyNotes {
                        Section("Safety Notes") {
                            Text(safetyNotes)
                                .accessibilityLabel("Safety Notes, \(safetyNotes)")
                        }
                    }
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
        model.load(id: horseID, in: context)
    }
}
