import SwiftData
import SwiftUI

struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @State private var model = AppointmentDetailModel()
    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false
    @State private var deletesAfterConfirmation = false
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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if hasSupplementalDetails(detail) {
                        Section("Details") {
                            if let address = detail.barnAddress {
                                LabeledContent("Address", value: address)
                                    .accessibilityIdentifier("appointment-detail-address")
                            }
                            if let arrivalNotes = detail.barnContactNotes {
                                LabeledContent("Arrival Notes", value: arrivalNotes)
                                    .accessibilityIdentifier(
                                        "appointment-detail-arrival-notes"
                                    )
                            }
                            if let duration = detail.expectedDurationMinutes {
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
                            if let notes = detail.notes {
                                LabeledContent("Notes", value: notes)
                            }
                        }
                        .listRowBackground(ColorTokens.surface)
                    }

                    Section("Horses") {
                        ForEach(detail.horses) { horse in
                            if let horseName = horse.name {
                                VStack(
                                    alignment: .leading,
                                    spacing: SpacingTokens.rowContent
                                ) {
                                    Text(horseName)
                                        .font(Typography.recordTitle)
                                    Text(
                                        horse.clientName
                                            ?? String(
                                                localized: "Client unavailable",
                                                locale: locale
                                            )
                                    )
                                        .font(Typography.recordMetadata)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                    if let serviceName = horse.plannedServiceName {
                                        LabeledContent("Service", value: serviceName)
                                            .font(Typography.recordMetadata)
                                            .accessibilityIdentifier("appointment-planned-service-\(horseName)")
                                    }
                                    if let phone = horse.clientPhone {
                                        Text(phone)
                                            .font(Typography.recordMetadata)
                                            .foregroundStyle(ColorTokens.textSecondary)
                                    }
                                    if let safetyNotes = horse.safetyNotes {
                                        Label {
                                            Text(safetyNotes)
                                                .foregroundStyle(ColorTokens.textPrimary)
                                        } icon: {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(ColorTokens.warning)
                                        }
                                        .font(Typography.recordMetadata)
                                    }
                                }
                            } else {
                                Text("Horse unavailable")
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(ColorTokens.surface)
                    if detail.visit == nil, subscription.allowsMutations {
                        Section {
                            Button {
                                guard subscription.allowsMutations else { return }
                                model.startVisit(
                                    in: context.container,
                                    analyticsClient: analyticsClient
                                )
                            } label: {
                                AppointmentActionLabel(
                                    title: "Start Visit",
                                    systemImage: "arrow.right"
                                )
                            }
                            .farrierFlowBorderedAction()
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
                }
                .listSectionSpacing(.custom(SpacingTokens.recordSection))
                .farrierFlowScrollBackground()
                .navigationTitle("Appointment")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let visit = detail.visit {
                            Button(visit.completedAt == nil && subscription.allowsMutations ? "Resume Visit" : "View Visit") {
                                if visit.completedAt == nil, !subscription.allowsMutations {
                                    model.visitPresentation = .detail(visit.id)
                                } else {
                                    model.present(
                                        visitID: visit.id,
                                        completedAt: visit.completedAt
                                    )
                                }
                            }
                            .accessibilityIdentifier(
                                visit.completedAt == nil
                                    ? (subscription.allowsMutations ? "visit-resume-action" : "visit-view-action")
                                    : "visit-view-action"
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
                }
                .sheet(
                    isPresented: $showsDeleteConfirmation,
                    onDismiss: handleDeletionSheetDismissal
                ) {
                    AppointmentDeletionSheet {
                        deletesAfterConfirmation = true
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
            || detail.notes != nil
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

    private func handleDeletionSheetDismissal() {
        guard deletesAfterConfirmation else { return }
        deletesAfterConfirmation = false
        guard subscription.allowsMutations else { return }
        if model.delete(in: ModelContext(context.container)) { dismiss() }
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

private struct AppointmentDeletionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.recordSection) {
                VStack(spacing: SpacingTokens.related) {
                    Image(systemName: "trash")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ColorTokens.destructive)
                        .frame(
                            width: SpacingTokens.hero,
                            height: SpacingTokens.hero
                        )
                        .background(ColorTokens.destructiveTint, in: Circle())
                        .accessibilityHidden(true)

                    VStack(spacing: SpacingTokens.compact) {
                        Text("Delete Appointment?")
                            .font(.title3.weight(.semibold))
                        Text("This appointment will be removed from your schedule.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: SpacingTokens.related) {
                    Button(role: .destructive) {
                        onConfirm()
                        dismiss()
                    } label: {
                        AppointmentActionLabel(
                            title: "Delete Appointment",
                            systemImage: "trash"
                        )
                    }
                    .farrierFlowBorderedAction(tint: ColorTokens.destructive)
                    .accessibilityIdentifier("appointment-delete-confirmation")

                    Button(role: .cancel) { dismiss() } label: {
                        AppointmentActionLabel(
                            title: "Cancel",
                            systemImage: "xmark"
                        )
                    }
                    .farrierFlowBorderedAction()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, SpacingTokens.section)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .farrierFlowScreenBackground()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("appointment-delete-sheet")
    }
}

private struct AppointmentSummaryHeader: View {
    let startDate: Date
    let serviceLocation: String
    let status: AppointmentDisplayStatus

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tight) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.related) {
                    dateText
                    Spacer(minLength: SpacingTokens.compact)
                    statusBadge
                }

                VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                    dateText
                    statusBadge
                }
            }

            Text(serviceLocation)
                .font(.title3)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.vertical, SpacingTokens.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(startDate.formatted(date: .abbreviated, time: .shortened)), \(serviceLocation)"
        )
        .accessibilityValue(String(localized: status.title))
    }

    private var dateText: some View {
        Text(
            startDate,
            format: .dateTime
                .weekday(.wide)
                .month(.abbreviated)
                .day()
                .year()
                .hour()
                .minute()
        )
        .font(.title2.weight(.bold))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusBadge: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.14), in: Capsule())
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

    var color: Color {
        switch self {
        case .scheduled: ColorTokens.textSecondary
        case .inProgress: ColorTokens.brandActionText
        case .completed: ColorTokens.success
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
