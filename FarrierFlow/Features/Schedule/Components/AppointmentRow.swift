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
            appointmentTime
            serviceLocation
            Text(horseNames)
                .font(Typography.recordMetadata)
            if dynamicTypeSize.isAccessibilitySize, let visit = appointment.visit {
                Text(visit.completedAt == nil ? "In Progress" : "Completed")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(visit.completedAt == nil ? ColorTokens.brandActionText : ColorTokens.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
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
            .foregroundStyle(ColorTokens.textSecondary)
    }
}
