import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schedule Appointment", systemImage: "plus") {
                        presentedSheet = .appointment
                    }
                }
            }
            .navigationDestination(for: TodayRoute.self) { route in
                destination(for: route)
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
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.businessName)
                        .font(.headline)
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            primaryActionContent

            if !model.remainingAppointments.isEmpty {
                Section("Schedule") {
                    ForEach(model.remainingAppointments) { appointment in
                        NavigationLink(
                            value: TodayRoute.appointment(appointment.id)
                        ) {
                            TodayAppointmentRow(summary: appointment)
                        }
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .refreshable { reload() }
    }

    @ViewBuilder
    private var primaryActionContent: some View {
        switch model.primaryAction {
        case .resumeVisit(let visit):
            Section {
                Button {
                    presentedSheet = .visit(visit.id)
                } label: {
                    TodayRunSheetBand(state: .active(visit))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(ColorTokens.surveyInk)
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
                .listRowBackground(ColorTokens.surveyInk)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("today-run-sheet-scheduled")
            }
        case .addClient:
            Section("First Customer") {
                Button {
                    presentedSheet = .client
                } label: {
                    Label("Add First Client", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("today-add-first-client")
                Text("Add an owner once, then attach their horses while scheduling work.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .createInvoice(let candidate):
            Section("Ready to Invoice") {
                NavigationLink(value: TodayRoute.createInvoice(candidate.clientID)) {
                    LabeledContent(candidate.clientName) {
                        Text("Create Invoice")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .reviewInvoice(let invoice):
            Section("Payment Status") {
                NavigationLink(value: TodayRoute.invoice(invoice.id)) {
                    LabeledContent("Invoice \(invoice.number)") {
                        Text(invoice.clientName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .scheduleAppointment:
            Section {
                ContentUnavailableView {
                    Label("No Stops Today", systemImage: "sun.max")
                } description: {
                    Text("Schedule the next barn or customer stop when you’re ready.")
                } actions: {
                    Button("Schedule Appointment") {
                        presentedSheet = .appointment
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
        case .createInvoice(let clientID):
            InvoiceCreationView(clientID: clientID) { invoiceID in
                if path.count > 0 { path.removeLast() }
                path.append(TodayRoute.invoice(invoiceID))
            }
        case .invoice(let id):
            InvoiceDetailView(invoiceID: id)
        }
    }

    private func reload() {
        model.load(in: context, now: .now, calendar: .autoupdatingCurrent)
    }

    private func handleSheetDismissal() {
        reload()
        guard let completedVisitID = pendingCompletedVisitID else { return }
        pendingCompletedVisitID = nil
        presentedSheet = .nextAppointment(completedVisitID)
    }
}

private enum TodayRoute: Hashable {
    case appointment(PersistentIdentifier)
    case createInvoice(PersistentIdentifier)
    case invoice(PersistentIdentifier)
}

private struct TodayAppointmentRow: View {
    let summary: TodayAppointmentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.startDate, format: .dateTime.hour().minute())
                .font(.headline)
                .monospacedDigit()
            Text(summary.serviceLocationName)
            Text(summary.horseNames.formatted(.list(type: .and)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TodayRunSheetBand: View {
    enum State {
        case scheduled(TodayAppointmentSummary)
        case active(TodayVisitSummary)
    }

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
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surveyInk)
        .foregroundStyle(.white)
    }

    private func scheduledContent(_ appointment: TodayAppointmentSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Next Stop")
                    .font(.headline)
                Spacer()
                Text("Scheduled")
                    .font(.subheadline.weight(.semibold))
            }
            Text(appointment.startDate, format: .dateTime.hour().minute())
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            recordDetails(
                location: appointment.serviceLocationName,
                address: appointment.serviceLocationAddress,
                horseNames: appointment.horseNames
            )
            Label("Open Appointment", systemImage: "arrow.right")
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Next Stop, Scheduled, \(appointment.startDate.formatted(date: .omitted, time: .shortened)), \(appointment.serviceLocationName), \(appointment.serviceLocationAddress ?? ""), \(appointment.horseNames.formatted(.list(type: .and))), Open Appointment"
        )
    }

    private func activeContent(_ visit: TodayVisitSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Next Action")
                    .font(.headline)
                Spacer()
                Text("Visit In Progress")
                    .font(.subheadline.weight(.semibold))
            }
            recordDetails(
                location: visit.serviceLocationName,
                address: visit.serviceLocationAddress,
                horseNames: visit.horseNames
            )
            ProgressView(
                value: Double(visit.resolvedHorseCount),
                total: Double(visit.totalHorseCount)
            )
            .tint(.white)
            Text("\(visit.resolvedHorseCount) of \(visit.totalHorseCount) horses resolved")
                .font(.subheadline)
                .monospacedDigit()
            Label("Resume Visit", systemImage: "arrow.right")
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Next Action, Visit In Progress, \(visit.serviceLocationName), \(visit.serviceLocationAddress ?? ""), \(visit.horseNames.formatted(.list(type: .and))), \(visit.resolvedHorseCount) of \(visit.totalHorseCount) horses resolved, Resume Visit"
        )
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
                    .foregroundStyle(.white.opacity(0.86))
            }
            Text(horseNames.formatted(.list(type: .and)))
                .font(.body)
                .foregroundStyle(.white.opacity(0.86))
        }
    }
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
    } else {
        ModelContainerFailureView()
    }
}
