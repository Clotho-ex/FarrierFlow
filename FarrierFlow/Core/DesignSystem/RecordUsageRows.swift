import SwiftUI

struct LinkedAppointmentRow: View {
    let appointment: RecordUsageSnapshot.AppointmentReference

    var body: some View {
        RecordNavigationLink(value: ClientRoute.appointment(appointment.id)) {
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text(appointment.startDate, format: .dateTime.month().day().year().hour().minute())
                    .font(Typography.recordTitle)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(appointment.location)
                Text(appointment.horseNames.joined(separator: ", "))
            }
            .font(Typography.recordMetadata)
            .foregroundStyle(ColorTokens.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the appointment details")
        }
        .accessibilityIdentifier("linked-appointment-\(appointment.location)")
    }
}

struct LinkedVisitRow: View {
    let visit: RecordUsageSnapshot.VisitReference

    var body: some View {
        RecordNavigationLink(value: ClientRoute.visit(visit.id)) {
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text(visit.startedAt, format: .dateTime.month().day().year().hour().minute())
                    .font(Typography.recordTitle)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(visit.location)
                Text(visit.horseNames.joined(separator: ", "))
                if !visit.serviceNames.isEmpty {
                    Text(visit.serviceNames.joined(separator: ", "))
                }
                Text(visit.isCompleted ? "Completed" : "In Progress")
                ForEach(visit.invoiceNumbers, id: \.self) { number in
                    Text("Invoice \(number)")
                }
            }
            .font(Typography.recordMetadata)
            .foregroundStyle(ColorTokens.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the visit details")
        }
        .accessibilityIdentifier("linked-visit-\(visit.horseNames.joined(separator: ", "))")
    }
}
