import SwiftData
import SwiftUI

struct StopDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: StopDetailsModel

    init(stop: TodayStopSummary) {
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
                    Text(stop.appointments.first?.serviceLocationName ?? "")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    let date = stop.id.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
                    let time = stop.id.startDate.formatted(.dateTime.hour().minute())
                    Text("\(date) · \(time)")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                    if let address = stop.appointments.first?.serviceLocationAddress {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today-stop-identity")
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(stop.appointments) { appointment in
                    NavigationLink(value: appointment.id) {
                        StopAppointmentRow(appointment: appointment)
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

    private var appointmentsHeading: some View {
        Text("Appointments").font(.headline).foregroundStyle(ColorTokens.textPrimary)
    }

    private func horseCount(_ stop: TodayStopSummary) -> some View {
        Text("\(stop.horseNames.count) horses").font(.subheadline)
    }

    private func reload() { model.load(in: context.container) }
}

private struct StopAppointmentRow: View {
    let appointment: TodayAppointmentSummary

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
        Text(appointment.horseNames.formatted(.list(type: .and)))
            .font(.headline)
            .foregroundStyle(ColorTokens.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var status: some View {
        Text(appointment.state.localizedTitle)
            .font(.subheadline)
            .foregroundStyle(ColorTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
