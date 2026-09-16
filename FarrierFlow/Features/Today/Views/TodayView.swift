import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(OnboardingExperienceModel.self) private var onboarding
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.appClock) private var appClock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path = NavigationPath()
    @State private var model = TodayModel()
    @State private var presentedSheet: TodaySheet?
    @State private var pendingCompletedVisitID: PersistentIdentifier?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch model.loadState {
                case .loading:
                    ProgressView("Loading Run Sheet…")
                case .failed:
                    unavailableContent
                case .loaded:
                    runSheet
                }
            }
            .navigationTitle("Today")
            .toolbarTitleDisplayMode(
                dynamicTypeSize.isAccessibilitySize ? .inline : .inlineLarge
            )
            .toolbar {
                if subscription.allowsMutations {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Schedule Appointment", systemImage: "plus") {
                            presentedSheet = .appointment
                        }
                    }
                }
            }
            .navigationDestination(for: TodayRoute.self) { route in
                destination(for: route)
            }
            .navigationDestination(for: SubscriptionRoute.self) { route in
                switch route {
                case .store:
                    SubscriptionView(
                        presentation: .standard(
                            showsManageSubscriptionButton: true
                        )
                    )
                }
            }
            .sheet(item: $presentedSheet, onDismiss: handleSheetDismissal) { sheet in
                switch sheet {
                case .appointment:
                    AppointmentEditorView()
                case .client:
                    ClientEditorView()
                case .visit(let id):
                    VisitEditorView(
                        visitID: id,
                        container: context.container
                    ) { completedVisitID in
                        pendingCompletedVisitID = completedVisitID
                    }
                case .nextAppointment(let visitID):
                    NextAppointmentAssistantView(visitID: visitID)
                }
            }
            .onAppear(perform: reload)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reload() }
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private var runSheet: some View {
        List {
            if !subscription.allowsMutations, subscription.access != .loading {
                Section {
                    SubscriptionReadOnlyNotice(access: subscription.access) {
                        path.append(SubscriptionRoute.store)
                    }
                }
                .listRowBackground(ColorTokens.surface)
            }

            if dynamicTypeSize.isAccessibilitySize {
                primaryActionContent
                identityContent
            } else {
                identityContent
                primaryActionContent
            }

            if !model.remainingAppointments.isEmpty {
                Section("Today’s Stops") {
                    ForEach(model.remainingAppointments.indices, id: \.self) { index in
                        let appointment = model.remainingAppointments[index]
                        RecordNavigationLink(
                            value: TodayRoute.appointment(appointment.id)
                        ) {
                            TodayAppointmentRow(
                                summary: appointment,
                                isFirst: index == 0,
                                isLast: index == model.remainingAppointments.count - 1
                            )
                        }
                        .badge(
                            dynamicTypeSize.isAccessibilitySize ? nil : Text(appointment.state.localizedTitle)
                                .foregroundStyle(appointment.state.emphasisColor)
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(ColorTokens.surface)
                    }
                }
            }
        }
        .listSectionSpacing(.custom(SpacingTokens.standard))
        .padding(.top, SpacingTokens.compact)
        .farrierFlowScrollBackground()
        .refreshable { reload() }
    }

    private var identityContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.businessName)
                    .font(.headline)
                Text(
                    appClock.now(),
                    format: .dateTime.weekday(.wide).month(.abbreviated).day()
                )
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var primaryActionContent: some View {
        switch model.primaryAction {
        case .resumeVisit(let visit):
            Section {
                Button {
                    if subscription.allowsMutations {
                        presentedSheet = .visit(visit.id)
                    } else {
                        path.append(TodayRoute.visit(visit.id))
                    }
                } label: {
                    TodayRunSheetBand(state: .active(visit))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.brandTint)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("today-run-sheet-active")
            }
        case .openAppointment(let appointment):
            Section {
                Button {
                    path.append(TodayRoute.appointment(appointment.id))
                } label: {
                    TodayRunSheetBand(state: .scheduled(appointment))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.brandTint)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("today-run-sheet-scheduled")
            }
        case .addClient where subscription.allowsMutations:
            Section("First Customer") {
                Button {
                    presentedSheet = .client
                } label: {
                    TodayPrimaryActionLabel(
                        title: "Add First Client",
                        detail: "Create the client record, then attach their horses while scheduling.",
                        systemImage: "person.badge.plus",
                        detailAccessibilityIdentifier: "today-add-first-client-context"
                    )
                }
                .accessibilityIdentifier("today-add-first-client")
                .listRowBackground(ColorTokens.surface)
            }
        case .createInvoice(let candidate) where subscription.allowsMutations:
            Section("Ready to Invoice") {
                Button {
                    onboarding.markInvoiceCreationHintSeen()
                    path.append(
                        TodayRoute.createInvoice(
                            clientID: candidate.clientID,
                            visitID: candidate.visitID
                        )
                    )
                } label: {
                    TodayPrimaryActionLabel(
                        title: "Create Invoice",
                        detail: onboarding.showsInvoiceCreationHint
                            ? "Completed work can now become a customer invoice."
                            : "Work complete for \(candidate.clientName) on \(candidate.workDate.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "doc.text",
                        detailAccessibilityIdentifier: "today-create-invoice-context"
                    )
                }
                .accessibilityIdentifier("today-create-invoice-action")
                .listRowBackground(ColorTokens.surface)
            }
        case .reviewInvoice(let invoice):
            Section("Payment Status") {
                RecordNavigationLink(value: TodayRoute.invoice(invoice.id)) {
                    TodayPrimaryActionLabel(
                        title: "Review Invoice \(invoice.number)",
                        detail: "\(invoice.clientName), issued \(invoice.invoiceDate.formatted(date: .abbreviated, time: .omitted)), payment pending",
                        systemImage: "creditcard",
                        detailAccessibilityIdentifier: "today-review-invoice-context"
                    )
                }
                .accessibilityIdentifier("today-review-invoice-action")
                .listRowBackground(ColorTokens.surface)
            }
        case .scheduleAppointment where subscription.allowsMutations:
            Section {
                ContentUnavailableView {
                    Label("Nothing Scheduled Yet", systemImage: "calendar.badge.plus")
                } description: {
                    Text("Your appointments will appear here.")
                } actions: {
                    Button("Schedule Appointment") {
                        presentedSheet = .appointment
                    }
                    .farrierFlowPrimaryAction()
                    .controlSize(.large)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        default:
            EmptyView()
        }
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("Run Sheet Unavailable", systemImage: "exclamationmark.circle")
        } description: {
            Text("FarrierFlow couldn’t load today’s work.")
        } actions: {
            Button("Retry", action: reload)
        }
    }

    @ViewBuilder
    private func destination(for route: TodayRoute) -> some View {
        switch route {
        case .appointment(let id):
            AppointmentDetailView(appointmentID: id) {
                path = NavigationPath()
            }
        case .createInvoice(let clientID, let visitID):
            InvoiceCreationView(
                clientID: clientID,
                initiallySelectedVisitID: visitID
            ) { invoiceID in
                if path.count > 0 { path.removeLast() }
                path.append(TodayRoute.invoice(invoiceID))
            }
        case .invoice(let id):
            InvoiceDetailView(invoiceID: id)
        case .visit(let id):
            VisitDetailView(visitID: id, container: context.container)
        }
    }

    private func reload() {
        model.load(in: context, now: appClock.now(), calendar: .autoupdatingCurrent)
    }

    private func handleSheetDismissal() {
        reload()
        guard let completedVisitID = pendingCompletedVisitID else { return }
        pendingCompletedVisitID = nil
        presentedSheet = .nextAppointment(completedVisitID)
    }
}

private struct TodayPrimaryActionLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let systemImage: String
    let detailAccessibilityIdentifier: String

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    TodayPrimaryActionMarker(
                        systemImage: systemImage,
                        fillsAvailableHeight: false
                    )
                    Text(title)
                        .font(.headline)
                }
                detailText
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        } else {
            HStack(alignment: .top, spacing: 12) {
                TodayPrimaryActionMarker(
                    systemImage: systemImage,
                    fillsAvailableHeight: true
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    detailText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }

    private var detailText: some View {
        Text(detail)
            .font(.subheadline)
            .foregroundStyle(ColorTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(detailAccessibilityIdentifier)
    }
}

private struct TodayPrimaryActionMarker: View {
    @ScaledMetric(relativeTo: .headline) private var markerSize = 24.0

    let systemImage: String
    let fillsAvailableHeight: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: 1)
                .frame(
                    maxHeight: fillsAvailableHeight ? .infinity : markerSize + 10
                )
                .foregroundStyle(ColorTokens.border)

            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTokens.brandActionText)
                .frame(width: markerSize, height: markerSize)
                .background(ColorTokens.surface, in: Circle())
        }
        .frame(width: markerSize)
        .frame(maxHeight: fillsAvailableHeight ? .infinity : nil)
        .accessibilityHidden(true)
    }
}

private enum TodayRoute: Hashable {
    case appointment(PersistentIdentifier)
    case createInvoice(
        clientID: PersistentIdentifier,
        visitID: PersistentIdentifier
    )
    case invoice(PersistentIdentifier)
    case visit(PersistentIdentifier)
}

private struct TodayAppointmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: TodayAppointmentSummary
    let isFirst: Bool
    let isLast: Bool

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityContent
        } else {
            standardContent
        }
    }

    private var standardContent: some View {
        HStack(alignment: .top, spacing: 12) {
            worklineMarker

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.startDate, format: .dateTime.hour().minute())
                    .font(.headline)
                    .monospacedDigit()
                locationText
                Text(summary.horseNames.formatted(.list(type: .and)))
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                worklineMarker

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.startDate, format: .dateTime.hour().minute())
                        .font(.headline)
                        .monospacedDigit()
                    Text(summary.state.localizedTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(summary.state.emphasisColor)
                }
            }

            locationText
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(todayHorseSummaryText(summary.horseNames))
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var worklineMarker: some View {
        TodayWorklineMarker(
            state: summary.state,
            isFirst: isFirst,
            isLast: isLast
        )
    }

    private var locationText: some View {
        Text(summary.serviceLocationName)
    }

    private var accessibilityLabel: String {
        "\(summary.startDate.formatted(date: .omitted, time: .shortened)), \(summary.serviceLocationName)"
    }

    private var accessibilityValue: String {
        let horseNames = summary.horseNames.formatted(.list(type: .and))
        return dynamicTypeSize.isAccessibilitySize
            ? "\(String(localized: summary.state.localizedTitle)), \(horseNames)"
            : horseNames
    }
}

private struct TodayWorklineMarker: View {
    @ScaledMetric(relativeTo: .body) private var markerSize = 20.0

    let state: TodayAppointmentState
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .frame(width: 1)
                .padding(.top, isFirst ? markerSize / 2 : 0)
                .padding(.bottom, isLast ? markerSize / 2 : 0)

            Image(systemName: state.systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: markerSize, height: markerSize)
                .background(ColorTokens.surface, in: Circle())
        }
        .foregroundStyle(ColorTokens.textSecondary)
        .frame(width: markerSize)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private extension TodayAppointmentState {
    var localizedTitle: LocalizedStringResource {
        switch self {
        case .scheduled:
            "Scheduled"
        case .inProgress:
            "In Progress"
        case .completed:
            "Work Complete"
        }
    }

    var systemImage: String {
        switch self {
        case .scheduled:
            "circle"
        case .inProgress:
            "circle.lefthalf.filled"
        case .completed:
            "checkmark.circle.fill"
        }
    }

    var emphasisColor: Color {
        switch self {
        case .scheduled:
            ColorTokens.textSecondary
        case .inProgress:
            ColorTokens.brandActionText
        case .completed:
            ColorTokens.success
        }
    }
}

private struct TodayRunSheetBand: View {
    @Environment(SubscriptionAccessModel.self) private var subscription

    enum State {
        case scheduled(TodayAppointmentSummary)
        case active(TodayVisitSummary)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .scheduled(let appointment):
                scheduledContent(appointment)
            case .active(let visit):
                activeContent(visit)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 16 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.brandTint)
        .foregroundStyle(ColorTokens.textPrimary)
    }

    private func scheduledContent(_ appointment: TodayAppointmentSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader(title: "Next Stop", status: "Scheduled")
            Text(appointment.startDate, format: .dateTime.hour().minute())
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? .title2.weight(.bold)
                        : .largeTitle.weight(.bold)
                )
                .monospacedDigit()
            recordDetails(
                location: appointment.serviceLocationName,
                address: appointment.serviceLocationAddress,
                horseNames: appointment.horseNames
            )
            Label("Open Appointment", systemImage: "arrow.right")
                .font(.headline)
                .foregroundStyle(ColorTokens.brandActionText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next stop, \(appointment.serviceLocationName)")
        .accessibilityValue(scheduledAccessibilityValue(appointment))
        .accessibilityHint("Opens appointment details.")
    }

    private func activeContent(_ visit: TodayVisitSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader(title: "Next Action", status: "Visit In Progress")
            recordDetails(
                location: visit.serviceLocationName,
                address: visit.serviceLocationAddress,
                horseNames: visit.horseNames
            )
            ProgressView(
                value: Double(visit.resolvedHorseCount),
                total: Double(visit.totalHorseCount)
            )
            .tint(ColorTokens.brandActionText)
            Text("\(visit.resolvedHorseCount) of \(visit.totalHorseCount) horses recorded")
                .font(.subheadline)
                .monospacedDigit()
            Label(activeActionLabel, systemImage: "arrow.right")
                .font(.headline)
                .foregroundStyle(ColorTokens.brandActionText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Visit in progress, \(visit.serviceLocationName)")
        .accessibilityValue(activeAccessibilityValue(visit))
        .accessibilityHint(
            subscription.allowsMutations
                ? "Resumes the visit."
                : "Opens visit details."
        )
    }

    @ViewBuilder
    private func statusHeader(
        title: LocalizedStringResource,
        status: LocalizedStringResource
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.brandActionText)
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(status)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTokens.brandActionText)
            }
        }
    }

    private var activeActionLabel: String {
        subscription.allowsMutations ? "Resume Visit" : "View Visit"
    }

    private func recordDetails(
        location: String,
        address: String?,
        horseNames: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location)
                .font(.title3.weight(.semibold))
            if let address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Text(todayHorseSummaryText(horseNames))
                .font(.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    private func scheduledAccessibilityValue(
        _ appointment: TodayAppointmentSummary
    ) -> String {
        let time = appointment.startDate.formatted(date: .omitted, time: .shortened)
        let schedule = String(
            localized: "Scheduled at \(time)",
            comment: "VoiceOver value for a scheduled appointment time."
        )
        return [
            schedule,
            appointment.serviceLocationAddress,
            todayHorseSummaryText(appointment.horseNames),
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private func activeAccessibilityValue(_ visit: TodayVisitSummary) -> String {
        let progress = String(
            localized: "\(visit.resolvedHorseCount) of \(visit.totalHorseCount) horses recorded",
            comment: "VoiceOver progress for horses recorded during the active visit."
        )
        return [
            progress,
            visit.serviceLocationAddress,
            todayHorseSummaryText(visit.horseNames),
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

}

private func todayHorseSummaryText(_ horseNames: [String]) -> String {
    let summary = TodayHorseSummary(horseNames: horseNames)
    let visibleNames = summary.visibleHorseNames.formatted(.list(type: .and))
    guard summary.remainingHorseCount > 0 else { return visibleNames }
    return String(
        localized: "\(visibleNames), and \(summary.remainingHorseCount) more horses",
        comment: "A shortened horse list followed by the number of additional horses."
    )
}

private enum TodaySheet: Identifiable {
    case appointment
    case client
    case visit(PersistentIdentifier)
    case nextAppointment(PersistentIdentifier)

    var id: String {
        switch self {
        case .appointment:
            "appointment"
        case .client:
            "client"
        case .visit(let id):
            "visit-\(String(describing: id))"
        case .nextAppointment(let id):
            "next-appointment-\(String(describing: id))"
        }
    }
}

#Preview("Today — Empty") {
    if let container = try? ModelContainerFactory.inMemoryTest() {
        TodayView()
            .modelContainer(container)
            .environment(
                SubscriptionAccessModel(
                    client: StaticSubscriptionClient(isPro: true)
                )
            )
    } else {
        ModelContainerFailureView()
    }
}
