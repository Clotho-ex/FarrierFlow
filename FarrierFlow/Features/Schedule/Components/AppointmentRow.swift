import SwiftUI

struct AppointmentRow: View {
    let appointment: Appointment

    private var horseNames: String {
        let names = appointment.appointmentHorses
            .compactMap(\.horse?.name)
            .sorted(using: String.StandardComparator(.localizedStandard))
        return names.isEmpty
            ? String(localized: "Horse unavailable")
            : names.formatted(.list(type: .and))
    }

    private var barnName: String {
        appointment.barn?.name ?? String(localized: "Service location unavailable")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            HStack {
                Text(appointment.startDate, format: .dateTime.hour().minute())
                    .font(Typography.recordTitle)
                Spacer()
                Text(barnName)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            Text(horseNames)
                .font(Typography.recordMetadata)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appointment-row-\(barnName)")
    }
}
