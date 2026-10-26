import SwiftUI

struct AppointmentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let startDate: Date
    let summary: AppointmentRowSummary

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.related) {
            headerLayout {
                Text(startDate, format: .dateTime.hour().minute())
                    .font(.title2.weight(.semibold))
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: SpacingTokens.compact) }
                Text(summary.state.title)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(statusColor(summary.state))
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text(verbatim: summary.barnName)
                    .font(Typography.recordTitle)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: summary.horseDetail)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let services = summary.plannedServices {
                Divider()
                headerLayout {
                    Text("Planned Services")
                        .foregroundStyle(ColorTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: SpacingTokens.compact) }
                    Text(verbatim: services)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(Typography.recordMetadata)
            }
        }
        .padding(.vertical, SpacingTokens.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .lineLimit(nil)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appointment-row-\(summary.barnName)")
    }

    private var headerLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.rowContent))
        } else {
            AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        }
    }

    private func statusColor(_ state: AppointmentRowSummary.State) -> Color {
        switch state {
        case .scheduled: ColorTokens.textSecondary
        case .inProgress: ColorTokens.brandActionText
        case .completed: ColorTokens.success
        }
    }
}
