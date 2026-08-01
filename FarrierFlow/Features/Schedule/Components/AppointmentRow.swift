import SwiftUI

struct AppointmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    appointmentTime
                    serviceLocation
                }
            } else {
                HStack {
                    appointmentTime
                    Spacer()
                    serviceLocation
                }
            }
            Text(horseNames)
                .font(Typography.recordMetadata)
            if let visit = appointment.visit {
                if visit.completedAt == nil {
                    Text("In Progress")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Completed")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appointment-row-\(barnName)")
    }

    private var appointmentTime: some View {
        Text(appointment.startDate, format: .dateTime.hour().minute())
            .font(Typography.recordTitle)
    }

    private var serviceLocation: some View {
        Text(barnName)
            .font(Typography.recordMetadata)
            .foregroundStyle(.secondary)
    }
}
