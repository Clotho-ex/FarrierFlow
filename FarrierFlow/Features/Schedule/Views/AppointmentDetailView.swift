import SwiftData
import SwiftUI

struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model = AppointmentDetailModel()
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false
    @State private var pendingCompletedVisitID: PersistentIdentifier?
    @State private var nextAppointmentVisitID: PersistentIdentifier?

    let appointmentID: PersistentIdentifier
    private let onVisitCompleted: (() -> Void)?

    init(
        appointmentID: PersistentIdentifier,
        onVisitCompleted: (() -> Void)? = nil
    ) {
        self.appointmentID = appointmentID
        self.onVisitCompleted = onVisitCompleted
    }

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
                        if let address = appointment.barn?.address {
                            LabeledContent("Address", value: address)
                                .accessibilityIdentifier("appointment-detail-address")
                        }
                        if let arrivalNotes = appointment.barn?.contactNotes {
                            LabeledContent("Arrival Notes", value: arrivalNotes)
                                .accessibilityIdentifier(
                                    "appointment-detail-arrival-notes"
                                )
                        }
                        if let duration = appointment.expectedDurationMinutes {
                            LabeledContent(
                                "Expected Duration",
                                value: AppointmentDurationFormatter.string(
                                    minutes: duration,
                                    locale: locale
                                )
                            )
                            .accessibilityIdentifier(
                                "appointment-detail-expected-duration"
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
                                    if let phone = horse.client?.phone {
                                        Text(phone)
                                            .font(Typography.recordMetadata)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let safetyNotes = horse.safetyNotes {
                                        Label(safetyNotes, systemImage: "exclamationmark.triangle")
                                            .font(Typography.recordMetadata)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            } else {
                                Text("Horse unavailable")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if appointment.visit == nil {
                        Section {
                            Button("Start Visit") {
                                model.startVisit(in: context.container)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("visit-start-action")
                        }
                    }
                }
                .navigationTitle(
                    appointment.barn?.name
                        ?? String(localized: "Appointment", locale: locale)
                )
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let visit = appointment.visit {
                            Button(
                                visit.completedAt == nil ? "Resume Visit" : "View Visit"
                            ) {
                                model.present(visit)
                            }
                            .accessibilityIdentifier(
                                visit.completedAt == nil
                                    ? "visit-resume-action"
                                    : "visit-view-action"
                            )
                        }
                        Button("Edit", systemImage: "pencil") { showsEditor = true }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("appointment-delete-action")
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
                        if model.delete(in: ModelContext(context.container)) { dismiss() }
                    }
                    .accessibilityIdentifier("appointment-delete-confirmation")
                }
            } else {
                ContentUnavailableView(
                    "Appointment Unavailable",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
        .onAppear(perform: reload)
        .sheet(item: editorPresentation, onDismiss: handleVisitEditorDismissal) { presentation in
            if case let .editor(visitID) = presentation {
                VisitEditorView(
                    visitID: visitID,
                    container: context.container
                ) { completedVisitID in
                    pendingCompletedVisitID = completedVisitID
                }
            }
        }
        .sheet(
            isPresented: nextAppointmentIsPresented,
            onDismiss: handleNextAppointmentDismissal
        ) {
            if let nextAppointmentVisitID {
                NextAppointmentAssistantView(visitID: nextAppointmentVisitID)
            }
        }
        .sheet(item: detailPresentation, onDismiss: reload) { presentation in
            if case let .detail(visitID) = presentation {
                VisitDetailView(
                    visitID: visitID,
                    container: context.container,
                    showsDismissAction: true
                )
            }
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
    }

    private func reload() {
        // Visit start and progress actions use their own contexts. Resolve the
        // Appointment in a fresh context after a sheet closes so stale state
        // cannot leave a Start Visit action visible.
        model.load(id: appointmentID, in: ModelContext(context.container))
    }

    private func handleVisitEditorDismissal() {
        reload()
        guard let completedVisitID = pendingCompletedVisitID else { return }
        pendingCompletedVisitID = nil
        nextAppointmentVisitID = completedVisitID
    }

    private func handleNextAppointmentDismissal() {
        reload()
        onVisitCompleted?()
    }

    private var nextAppointmentIsPresented: Binding<Bool> {
        Binding(
            get: { nextAppointmentVisitID != nil },
            set: { isPresented in
                if !isPresented {
                    nextAppointmentVisitID = nil
                }
            }
        )
    }

    private var editorPresentation: Binding<VisitPresentation?> {
        Binding(
            get: { model.editorPresentation },
            set: { model.editorPresentation = $0 }
        )
    }

    private var detailPresentation: Binding<VisitPresentation?> {
        Binding(
            get: { model.detailPresentation },
            set: { model.detailPresentation = $0 }
        )
    }
}
