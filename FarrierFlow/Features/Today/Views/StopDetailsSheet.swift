import SwiftData
import SwiftUI

struct StopDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appClock) private var appClock
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: StopDetailsModel
    @State private var alert: FeatureAlert?
    private let onVisitRequested: (PersistentIdentifier) -> Void

    init(stop: TodayStopSummary, onVisitRequested: @escaping (PersistentIdentifier) -> Void) {
        self.onVisitRequested = onVisitRequested
        _model = State(initialValue: StopDetailsModel(stop: stop))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let stop = model.stop {
                    stopContent(stop)
                } else if model.loadState == .loading {
                    ProgressView()
                } else if model.loadState == .failed {
                    ContentUnavailableView {
                        Label("Couldn’t Load Stop", systemImage: "exclamationmark.circle")
                    } actions: {
                        Button("Retry", action: reload)
                    }
                } else {
                    ContentUnavailableView("Stop Unavailable", systemImage: "calendar")
                }
            }
            .navigationTitle("Stop Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                        .accessibilityIdentifier("stop-details-close")
                }
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                AppointmentDetailView(appointmentID: id) { dismiss() }
            }
            .onAppear(perform: reload)
        }
        .presentationDetents(
            dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large]
        )
        .presentationDragIndicator(.visible)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let stop = model.stop, stop.id.state != .completed, subscription.allowsMutations {
                stopAction(stop)
                    .padding(SpacingTokens.standard)
                    .background(ColorTokens.background)
            }
        }
        .alert(item: $alert) { Alert(title: Text($0.title), message: Text($0.message)) }
        .onReceive(
            ModelSaveChanges.publisher(in: context.container, entities: [
                "Appointment", "AppointmentHorse", "Barn", "Horse", "Visit"
            ])
        ) {
            reload()
        }
    }

    private func stopContent(_ stop: TodayStopSummary) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                    VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                        Text(stop.appointments.first?.serviceLocationName ?? "")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        let date = stop.id.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
                        let time = stop.id.startDate.formatted(.dateTime.hour().minute())
                        Text("\(date) · \(time)")
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("today-stop-identity")
                    if let address = stop.appointments.first?.serviceLocationAddress {
                        ServiceLocationAddress(address: address, title: "Directions")
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(stop.appointments) { appointment in
                    NavigationLink(value: appointment.id) {
                        StopAppointmentRow(appointment: appointment, clientName: model.clientNamesByAppointment[appointment.id])
                    }
                    .accessibilityHint("Opens appointment details.")
                    .accessibilityIdentifier("today-stop-appointment")
                }
                .listRowBackground(ColorTokens.recordSurface)
            } header: {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        appointmentsHeading
                        Spacer(minLength: SpacingTokens.compact)
                        horseCount(stop)
                    }
                    VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                        appointmentsHeading
                        horseCount(stop)
                    }
                }
                .foregroundStyle(ColorTokens.textSecondary)
                .textCase(nil)
            }
        }
        .accessibilityIdentifier("stop-details-list")
        .listSectionSpacing(.custom(SpacingTokens.standard))
        .contentMargins(.top, 0, for: .scrollContent)
        .listRowSeparatorTint(ColorTokens.border)
        .farrierFlowScrollBackground()
    }

    @ViewBuilder
    private func stopAction(_ stop: TodayStopSummary) -> some View {
        if let appointment = stop.appointments.first, stop.appointments.count == 1 {
            Button {
                enterVisit(appointment.id)
            } label: {
                Text(stop.id.state == .inProgress ? "Resume Visit" : "Start Visit")
                    .frame(maxWidth: .infinity)
            }
            .font(.headline)
            .farrierFlowPrimaryAction()
            .controlSize(.large)
            .accessibilityIdentifier("stop-start-resume-visit")
        } else {
            Menu {
                ForEach(stop.appointments) { appointment in
                    Button(appointment.horseNames.formatted(.list(type: .and))) { enterVisit(appointment.id) }
                }
            } label: {
                Text(stop.id.state == .inProgress ? "Resume Visit" : "Start Visit")
                    .frame(maxWidth: .infinity)
            }
            .font(.headline)
            .farrierFlowPrimaryAction()
            .controlSize(.large)
            .accessibilityIdentifier("stop-start-resume-visit")
        }
    }

    private func enterVisit(_ appointmentID: PersistentIdentifier) {
        guard subscription.allowsMutations else { return }
        do {
            let id = try model.startOrResume(appointmentID: appointmentID, now: appClock.now(),
                in: context.container, analyticsClient: analyticsClient)
            onVisitRequested(id)
        } catch {
            alert = FeatureAlert(title: "Couldn’t Open Visit",
                message: "Refresh this stop and try again. Completed visits cannot be started again.")
            reload()
        }
    }

    private var appointmentsHeading: some View {
        Text("Appointments").recordSectionHeading()
    }

    private func horseCount(_ stop: TodayStopSummary) -> some View {
        Text("\(stop.horseNames.count) horses").font(.subheadline)
    }

    private func reload() { model.load(in: context.container) }
}

private struct StopAppointmentRow: View {
    let appointment: TodayAppointmentSummary
    let clientName: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.compact) {
                horseNames
                Spacer(minLength: SpacingTokens.compact)
                status.fixedSize()
            }
            VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                horseNames
                status
            }
        }
        .padding(.vertical, SpacingTokens.compact)
        .contentShape(Rectangle())
    }

    private var horseNames: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(appointment.horseNames.formatted(.list(type: .and)))
                .font(.headline)
                .foregroundStyle(ColorTokens.textPrimary)
            if let clientName, !clientName.isEmpty {
                Text(verbatim: clientName)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var status: some View {
        Text(appointment.state.localizedTitle)
            .font(.subheadline)
            .foregroundStyle(ColorTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
