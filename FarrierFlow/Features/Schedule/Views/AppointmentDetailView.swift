import SwiftData
import SwiftUI

struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model = AppointmentDetailModel()
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false

    let appointmentID: PersistentIdentifier

    var body: some View {
        Group {
            if let appointment = model.appointment {
                List {
                    Section("Appointment") {
                        LabeledContent(
                            "Starts",
                            value: appointment.startDate.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        LabeledContent(
                            "Service Location",
                            value: appointment.barn?.name
                                ?? String(localized: "Unavailable", locale: locale)
                        )
                        if let duration = appointment.expectedDurationMinutes {
                            LabeledContent(
                                "Expected Duration",
                                value: AppointmentDurationFormatter.string(
                                    minutes: duration,
                                    locale: locale
                                )
                            )
                        }
                        if let notes = appointment.notes {
                            LabeledContent("Notes", value: notes)
                        }
                    }
                    Section("Horses") {
                        ForEach(appointment.appointmentHorses, id: \.persistentModelID) { join in
                            if let horse = join.horse {
                                VStack(
                                    alignment: .leading,
                                    spacing: SpacingTokens.rowContent
                                ) {
                                    Text(horse.name)
                                        .font(Typography.recordTitle)
                                    Text(
                                        horse.client?.name
                                            ?? String(
                                                localized: "Client unavailable",
                                                locale: locale
                                            )
                                    )
                                        .font(Typography.recordMetadata)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Horse unavailable")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle(
                    appointment.barn?.name
                        ?? String(localized: "Appointment", locale: locale)
                )
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit", systemImage: "pencil") { showsEditor = true }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    AppointmentEditorView(appointment: appointment)
                }
                .confirmationDialog(
                    "Delete Appointment?",
                    isPresented: $showsDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Appointment", role: .destructive) {
                        if model.delete(in: context) { dismiss() }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Appointment Unavailable",
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
        model.load(id: appointmentID, in: context)
    }
}
