import SwiftData
import SwiftUI

struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appClock) private var appClock
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
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
            if let detail = model.detail {
                List {
                    Section {
                        AppointmentSummaryHeader(
                            startDate: detail.startDate,
                            serviceLocation: detail.barnName
                                ?? String(localized: "Unavailable", locale: locale),
                            status: AppointmentDisplayStatus(visit: detail.visit)
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if let visit = detail.visit, visit.completedAt != nil {
                        Section {
                            Button {
                                model.present(visitID: visit.id, completedAt: visit.completedAt)
                            } label: {
                                LabeledContent {
                                    Image(systemName: "arrow.right")
                                        .accessibilityHidden(true)
                                } label: {
                                    Text("View Completed Visit")
                                }
                            }
                            .foregroundStyle(ColorTokens.textPrimary)
                            .accessibilityIdentifier("visit-view-action")
                        }
                        .listRowBackground(ColorTokens.recordSurface)
                    }

                    if detail.visit == nil, subscription.allowsMutations {
                        Section {
                            Button {
                                guard subscription.allowsMutations else { return }
                                model.startVisit(
                                    now: appClock.now(),
                                    in: context.container,
                                    analyticsClient: analyticsClient
                                )
                            } label: {
                                AppointmentActionLabel(
                                    title: "Start Visit",
                                    systemImage: "arrow.right"
                                )
                            }
                            .farrierFlowPrimaryAction()
                            .controlSize(.large)
                            .accessibilityIdentifier("visit-start-action")
                        }
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 20,
                                bottom: SpacingTokens.standard,
                                trailing: 20
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if hasSupplementalDetails(detail) {
                        RecordSection(Text("Details")) {
                            if let address = detail.barnAddress {
                                ServiceLocationAddress(address: address, title: "Address")
                                    .accessibilityIdentifier("appointment-detail-address")
                            }
                            if let arrivalNotes = detail.barnContactNotes {
                                RecordDetailField("Arrival Notes") { Text(arrivalNotes) }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier(
                                        "appointment-detail-arrival-notes"
                                    )
                            }
                            if let duration = detail.expectedDurationMinutes {
                                RecordDetailField("Expected Duration") {
                                    Text(AppointmentDurationFormatter.string(
                                        minutes: duration,
                                        locale: locale
                                    ))
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier(
                                    "appointment-detail-expected-duration"
                                )
                            }
                            if let notes = TextNormalization.optional(detail.notes ?? "") {
                                AppointmentNoteView(note: notes)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("appointment-detail-notes")
                            }
                        }
                        .listRowBackground(ColorTokens.recordSurface)
                    }

                    RecordSection(Text("Horses")) {
                        ForEach(detail.horses) { horse in
                            if let horseName = horse.name {
                                VStack(alignment: .leading, spacing: SpacingTokens.standard) {
                                    VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                                        Text(verbatim: horseName)
                                            .font(Typography.recordTitle)
                                        if let safetyNotes = horse.safetyNotes {
                                            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.compact) {
                                                Image(systemName: "exclamationmark.triangle")
                                                    .foregroundStyle(ColorTokens.warning)
                                                    .accessibilityHidden(true)
                                                Text(verbatim: safetyNotes)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .font(.subheadline)
                                            .foregroundStyle(ColorTokens.textPrimary)
                                            .accessibilityElement(children: .combine)
                                            .accessibilityLabel("Safety note for \(horseName): \(safetyNotes)")
                                            .accessibilityIdentifier("appointment-safety-\(horseName)")
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                                        Text("Owner")
                                            .font(.subheadline)
                                            .foregroundStyle(ColorTokens.textSecondary)
                                        Text(verbatim: horse.clientName ?? String(localized: "Client unavailable", locale: locale))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    if detail.visit?.completedAt == nil,
                                       let serviceName = horse.plannedServiceName {
                                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                                            Text("Planned Service")
                                                .font(.subheadline)
                                                .foregroundStyle(ColorTokens.textSecondary)
                                            Text(verbatim: serviceName)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityIdentifier("appointment-planned-service-\(horseName)")
                                    }
                                }
                            } else {
                                Text("Horse unavailable")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(ColorTokens.recordSurface)

                    if detail.visit?.completedAt != nil,
                       detail.horses.contains(where: { $0.plannedServiceName != nil }) {
                        Section {
                            DisclosureGroup {
                                ForEach(detail.horses) { horse in
                                    if let serviceName = horse.plannedServiceName {
                                        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                                            Text(verbatim: horse.name ?? String(localized: "Horse unavailable", locale: locale))
                                                .font(.subheadline)
                                                .foregroundStyle(ColorTokens.textSecondary)
                                            Text(serviceName)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityIdentifier("appointment-original-plan-\(horse.name ?? "unavailable")")
                                    }
                                }
                            } label: {
                                Text("Original Planned Services")
                                    .accessibilityIdentifier("appointment-original-plan")
                            }
                        }
                        .listRowBackground(ColorTokens.recordSurface)
                    }

                }
                .listSectionSpacing(.custom(SpacingTokens.standard))
                .contentMargins(.top, 0, for: .scrollContent)
                .listRowSeparatorTint(ColorTokens.border)
                .farrierFlowScrollBackground()
                .navigationTitle("Appointment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let visit = detail.visit, visit.completedAt == nil {
                            Button(subscription.allowsMutations ? "Resume Visit" : "View Visit") {
                                if !subscription.allowsMutations {
                                    model.visitPresentation = .detail(visit.id)
                                } else {
                                    model.present(
                                        visitID: visit.id,
                                        completedAt: visit.completedAt
                                    )
                                }
                            }
                            .accessibilityIdentifier(
                                subscription.allowsMutations ? "visit-resume-action" : "visit-view-action"
                            )
                        }
                        if subscription.allowsMutations {
                            Menu {
                                Button("Edit Appointment", systemImage: "pencil") {
                                    showsEditor = true
                                }
                                .accessibilityIdentifier("appointment-edit-action")

                                Divider()

                                Button(
                                    "Delete Appointment",
                                    systemImage: "trash",
                                    role: .destructive
                                ) {
                                    showsDeleteConfirmation = true
                                }
                                .accessibilityIdentifier("appointment-delete-action")
                            } label: {
                                Label(
                                    "Appointment Actions",
                                    systemImage: "ellipsis"
                                )
                            }
                            .tint(ColorTokens.textSecondary)
                            .accessibilityIdentifier("appointment-actions-menu")
                        }
                    }
                }
                .sheet(isPresented: $showsEditor, onDismiss: reload) {
                    AppointmentEditorDestination(appointmentID: appointmentID)
                        .dynamicTypeSize(dynamicTypeSize)
                }
                .recordDeletionConfirmation(
                    .appointment(appointmentID), isPresented: $showsDeleteConfirmation,
                    title: "Delete Appointment?", confirmationTitle: "Delete Appointment",
                    accessibilityPrefix: "appointment-delete", alert: $model.alert
                ) { dismiss() }
            } else {
                ContentUnavailableView(
                    "Appointment Unavailable",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
        .onAppear(perform: reload)
        .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
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
        // Visit start and progress actions use their own contexts. Rebuild the
        // value detail in a fresh context so stale state cannot leave a Start
        // Visit action visible.
        model.load(id: appointmentID, in: ModelContext(context.container))
    }

    private func hasSupplementalDetails(_ detail: AppointmentDetail) -> Bool {
        detail.barnAddress != nil
            || detail.barnContactNotes != nil
            || detail.expectedDurationMinutes != nil
            || TextNormalization.optional(detail.notes ?? "") != nil
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

private struct AppointmentActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: SpacingTokens.compact) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(
                    width: SpacingTokens.section,
                    height: SpacingTokens.section
                )
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppointmentSummaryHeader: View {
    let startDate: Date
    let serviceLocation: String
    let status: AppointmentDisplayStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(startDate, format: .dateTime.hour().minute())
                .font(.title.weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("appointment-summary-time")
            Text(startDate, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    statusBadge.fixedSize()
                    locationText
                }
                VStack(alignment: .leading, spacing: 8) {
                    statusBadge
                    locationText
                }
            }
        }
        .padding(.vertical, SpacingTokens.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("appointment-summary")
        .accessibilityLabel(
            "\(startDate.formatted(date: .abbreviated, time: .shortened)), \(serviceLocation)"
        )
        .accessibilityValue(String(localized: status.title))
    }

    private var locationText: some View {
        Text(serviceLocation)
            .font(.headline)
            .foregroundStyle(ColorTokens.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if case .completed = status {
            CompletedStatusPill()
        } else {
            RecordStatusPill(title: status.title, tone: status.tone)
        }
    }
}

private enum AppointmentDisplayStatus {
    case scheduled
    case inProgress
    case completed

    init(visit: AppointmentDetail.Visit?) {
        guard let visit else {
            self = .scheduled
            return
        }
        self = visit.completedAt == nil ? .inProgress : .completed
    }

    var title: LocalizedStringResource {
        switch self {
        case .scheduled: "Scheduled"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        }
    }

    var tone: StatusTone {
        switch self {
        case .scheduled: .neutral
        case .inProgress: .active
        case .completed: .success
        }
    }
}

private struct AppointmentEditorDestination: View {
    @Environment(\.modelContext) private var context

    let appointmentID: PersistentIdentifier

    var body: some View {
        if let appointment = try? context.existingModel(
            Appointment.self,
            for: appointmentID
        ) {
            AppointmentEditorView(appointment: appointment)
        } else {
            ContentUnavailableView(
                "Appointment Unavailable",
                systemImage: "exclamationmark.circle"
            )
        }
    }
}
