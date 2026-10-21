import SwiftData
import SwiftUI

struct TodayView: View {
    let showSchedule: () -> Void

    @Environment(OnboardingExperienceModel.self) private var onboarding
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @Environment(\.appClock) private var appClock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path = NavigationPath()
    @State private var model = TodayModel()
    @State private var scheduleNow: Date?
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
                    if let emptyState = model.emptyState, model.remainingStops.isEmpty {
                        emptyRunSheet(emptyState)
                    } else {
                        runSheet
                    }
                }
            }
            .navigationTitle("Today")
            .toolbarTitleDisplayMode(
                dynamicTypeSize.isAccessibilitySize ? .inline : .inlineLarge
            )
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
                case .stop(let stop):
                    StopDetailsSheet(stop: stop)
                        .dynamicTypeSize(dynamicTypeSize)
                case .appointment:
                    AppointmentEditorView()
                case .client:
                    ClientEditorView()
                case .horse(let clientID):
                    HorseEditorView(preselectedClientID: clientID)
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
            .task(id: scheduledStartDates) {
                await updateScheduleClock(at: scheduledStartDates)
            }
            .onChange(of: backupSync?.runtime?.recordsVersion) { _, _ in reload() }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
                guard let savedContext = notification.object as? ModelContext,
                      savedContext.container === context.container else { return }
                reload()
            }
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

            identityContent
            if model.dayIsComplete, model.emptyState == nil {
                Section {
                    VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                        Label("All done for today", systemImage: "checkmark.circle")
                            .font(.headline)
                        Text("All of today’s scheduled stops are complete.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            primaryActionContent

            stopSection(
                model.remainingStops.filter { $0.id.state != .completed },
                title: nil
            )
            stopSection(
                model.remainingStops.filter { $0.id.state == .completed },
                title: "Completed Today"
            )
        }
        .listSectionSpacing(.custom(20))
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 0, for: .scrollContent)
        .farrierFlowScrollBackground()
        .refreshable { reload() }
    }

    private var identityContent: some View {
        Section {
            dateText
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var dateText: some View {
        Text(appClock.now(), format: .dateTime.weekday(.wide).month(.wide).day())
            .font(.subheadline)
            .foregroundStyle(ColorTokens.textSecondary)
    }

    private func emptyRunSheet(_ state: TodayEmptyState) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    dateText
                    if !subscription.allowsMutations, subscription.access != .loading {
                        SubscriptionReadOnlyNotice(access: subscription.access) {
                            path.append(SubscriptionRoute.store)
                        }
                        .padding(.top, SpacingTokens.section)
                    }
                    Spacer(minLength: SpacingTokens.section)
                    emptyStateContent(state)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: SpacingTokens.section)
                }
                .padding(.horizontal, SpacingTokens.standard)
                .padding(.bottom, SpacingTokens.section)
                .frame(minHeight: geometry.size.height)
            }
            .refreshable { reload() }
        }
        .farrierFlowScreenBackground()
    }

    private func emptyStateContent(_ state: TodayEmptyState) -> some View {
        ContentUnavailableView {
            switch state {
            case .addClient where subscription.allowsMutations:
                Label("Add your first client", systemImage: "person.badge.plus")
            case .addHorse where subscription.allowsMutations:
                Label("Add your first horse", systemImage: "plus")
            case .addClient, .addHorse, .noAppointments:
                Label("No appointments scheduled", systemImage: "calendar.badge.plus")
            case .noStops:
                Label("No stops today", systemImage: "calendar")
            case .allDone:
                Label("All done for today", systemImage: "checkmark.circle")
            }
        } description: {
            emptyStateDescription(state)
                .frame(maxWidth: 320)
        } actions: {
            switch state {
            case .addClient where subscription.allowsMutations:
                Button("Add Client") { presentedSheet = .client }
                    .farrierFlowPrimaryAction()
                    .controlSize(.large)
                    .accessibilityIdentifier("today-add-first-client")
            case .addHorse where subscription.allowsMutations:
                Button("Add Horse") {
                    if case .addHorse(let clientID) = model.primaryAction {
                        presentedSheet = .horse(clientID)
                    }
                }
                .farrierFlowPrimaryAction()
                .controlSize(.large)
                .accessibilityIdentifier("today-add-first-horse")
            case .noAppointments where subscription.allowsMutations:
                Button {
                    presentedSheet = .appointment
                } label: {
                    ViewThatFits(in: .horizontal) {
                        Text("Schedule Appointment").fixedSize()
                        Text("Schedule")
                    }
                }
                .accessibilityLabel("Schedule Appointment")
                .farrierFlowPrimaryAction()
                .controlSize(.large)
            case .noStops, .allDone:
                Button("View Schedule", action: showSchedule)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func emptyStateDescription(_ state: TodayEmptyState) -> some View {
        switch state {
        case .addClient where subscription.allowsMutations:
            Text("Start with a client, then add their horses and schedule work.")
        case .addHorse where subscription.allowsMutations:
            Text("Add a client’s horse and service location, then schedule work.")
        case .addClient, .addHorse, .noAppointments:
            if subscription.allowsMutations {
                Text("Schedule your first appointment to start planning your work.")
            } else {
                Text("There are no appointments in your schedule.")
            }
        case .noStops(let nextAppointment):
            if let nextAppointment {
                Text("Your day is clear. Your next appointment is \(nextAppointment, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute()).")
            } else {
                Text("Your day is clear.")
            }
        case .allDone:
            Text("All of today’s scheduled stops are complete.")
        }
    }

    @ViewBuilder
    private func stopSection(_ stops: [TodayStopSummary], title: LocalizedStringResource?) -> some View {
        if !stops.isEmpty {
            Section {
                ForEach(stops) { stop in
                    Button {
                        presentedSheet = .stop(stop)
                    } label: {
                        TodayStopRow(stop: stop)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .buttonStyle(.automatic)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(ColorTokens.recordSurface)
                    .accessibilityIdentifier("today-stop-row")
                }
            } header: {
                if let title {
                    stopSectionHeader(title: title, count: stops.count)
                } else {
                    stopSectionHeader(
                        title: model.remainingSectionTitle(at: scheduleNow ?? appClock.now()),
                        count: stops.count
                    )
                }
            }
        }
    }

    private var scheduledStartDates: [Date] {
        var dates = model.remainingStops
            .filter { $0.id.state != .completed }
            .map(\.id.startDate)
        if case .openAppointment(let appointment) = model.primaryAction {
            dates.append(appointment.startDate)
        }
        dates.append(CalendarRules.dayInterval(containing: appClock.now(), calendar: .autoupdatingCurrent).end)
        return Set(dates).sorted()
    }

    private func updateScheduleClock(at dates: [Date]) async {
        guard model.loadState == .loaded else { return }
        let dayEnd = CalendarRules.dayInterval(containing: appClock.now(), calendar: .autoupdatingCurrent).end
        scheduleNow = appClock.now()
        for date in Set(dates).sorted() {
            let delay = date.timeIntervalSince(appClock.now())
            guard delay > 0 else { continue }
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return // The run sheet disappeared or its scheduled starts changed.
            }
            guard !Task.isCancelled else { return }
            if appClock.now() >= dayEnd {
                reload()
                return
            }
            scheduleNow = appClock.now()
        }
    }

    private func stopSectionHeader(title: LocalizedStringResource, count: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Text("\(count) stops").font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text("\(count) stops").font(.subheadline)
            }
        }
        .foregroundStyle(ColorTokens.textSecondary)
        .textCase(nil)
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
                    TodayRunSheetBand(state: .active(visit), now: scheduleNow ?? appClock.now())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.featuredSurface)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("today-run-sheet-active")
            }
        case .openAppointment(let appointment):
            Section {
                Button {
                    if let stop = model.featuredStop {
                        presentedSheet = .stop(stop)
                    }
                } label: {
                    TodayRunSheetBand(state: .scheduled(appointment, model.featuredStop), now: scheduleNow ?? appClock.now())
                }
                .buttonStyle(.automatic)
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.featuredSurface)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("today-run-sheet-scheduled")
            }
        case .addClient, .addHorse, .scheduleAppointment:
            if let emptyState = model.emptyState {
                Section {
                    emptyStateContent(emptyState)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
        let now = appClock.now()
        scheduleNow = now
        model.load(in: context, now: now, calendar: .autoupdatingCurrent)
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
    case createInvoice(
        clientID: PersistentIdentifier,
        visitID: PersistentIdentifier
    )
    case invoice(PersistentIdentifier)
    case visit(PersistentIdentifier)
}

private struct TodayStopRow: View {
    let stop: TodayStopSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    timeText
                    Spacer(minLength: 8)
                    metadataGroup.fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    timeText
                    Text(metadataText)
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let appointment = stop.appointments.first {
                Text(appointment.serviceLocationName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(todayHorseSummaryText(stop.horseNames))
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stop.id.startDate.formatted(date: .omitted, time: .shortened)), \(stop.appointments.first?.serviceLocationName ?? "")")
        .accessibilityValue("\(metadataText), \(stop.horseNames.formatted(.list(type: .and)))")
        .accessibilityHint("Opens stop details.")
    }

    private var timeText: some View {
        Text(stop.id.startDate, format: .dateTime.hour().minute())
            .font(.headline)
            .monospacedDigit()
    }

    private var horseCountText: String {
        String(localized: "\(stop.horseNames.count) horses")
    }

    private var metadataText: String {
        let status = String(localized: stop.id.state.localizedTitle)
        return String(
            localized: "\(horseCountText) · \(status)",
            comment: "Horse count followed by appointment status in a Today stop’s metadata."
        )
    }

    private var metadataGroup: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(horseCountText)
            Text(verbatim: "·").accessibilityHidden(true)
            Text(stop.id.state.localizedTitle)
        }
        .font(.subheadline)
        .foregroundStyle(ColorTokens.textSecondary)
    }
}

private struct TodayRunSheetBand: View {
    @Environment(SubscriptionAccessModel.self) private var subscription

    enum State {
        case scheduled(TodayAppointmentSummary, TodayStopSummary?)
        case active(TodayVisitSummary)
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: State
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .scheduled(let appointment, let stop):
                scheduledContent(appointment, stop: stop)
            case .active(let visit):
                activeContent(visit)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(ColorTokens.featuredSurface)
        .foregroundStyle(ColorTokens.textPrimary)
    }

    private func scheduledContent(_ appointment: TodayAppointmentSummary, stop: TodayStopSummary?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader(title: appointment.heading(at: now), status: "Scheduled")
            Text(appointment.startDate, format: .dateTime.hour().minute())
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? .title2.weight(.bold)
                        : .title.weight(.bold)
                )
                .monospacedDigit()
            recordDetails(
                location: appointment.serviceLocationName,
                address: appointment.serviceLocationAddress,
                horseNames: stop?.horseNames ?? appointment.horseNames
            )
            Label("Open Stop", systemImage: "arrow.right")
                .font(.headline)
                .foregroundStyle(ColorTokens.brandActionText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(localized: appointment.heading(at: now))), \(appointment.serviceLocationName)")
        .accessibilityValue(scheduledAccessibilityValue(appointment, horseNames: stop?.horseNames ?? appointment.horseNames))
        .accessibilityHint("Opens stop details.")
    }

    private func activeContent(_ visit: TodayVisitSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader(title: "Continue Visit", status: "In Progress", tone: .active)
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
        status: LocalizedStringResource,
        tone: StatusTone = .neutral
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                RecordStatusPill(title: status, tone: tone)
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                RecordStatusPill(title: status, tone: tone)
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
        _ appointment: TodayAppointmentSummary,
        horseNames: [String]
    ) -> String {
        let time = appointment.startDate.formatted(date: .omitted, time: .shortened)
        let schedule = String(
            localized: "Scheduled at \(time)",
            comment: "VoiceOver value for a scheduled appointment time."
        )
        return [
            schedule,
            appointment.serviceLocationAddress,
            todayHorseSummaryText(horseNames),
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
    case stop(TodayStopSummary)
    case appointment
    case client
    case horse(PersistentIdentifier?)
    case visit(PersistentIdentifier)
    case nextAppointment(PersistentIdentifier)

    var id: String {
        switch self {
        case .stop(let stop):
            "stop-\(String(describing: stop.id))"
        case .appointment:
            "appointment"
        case .client:
            "client"
        case .horse:
            "horse"
        case .visit(let id):
            "visit-\(String(describing: id))"
        case .nextAppointment(let id):
            "next-appointment-\(String(describing: id))"
        }
    }
}

#Preview("Today — Empty") {
    if let container = try? ModelContainerFactory.inMemoryTest() {
        TodayView(showSchedule: {})
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
