import SwiftUI

struct InvoiceVisitSelectionRow: View {
    @Environment(\.locale) private var locale
    let choice: InvoiceVisitChoice
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: SpacingTokens.rowContent) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    Text(choice.visitDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(Typography.recordTitle)
                    Text(choice.serviceLocationName)
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(subtotal)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Visit on \(choice.visitDate.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Includes all eligible recorded work for this client.")
    }

    private var subtotal: String {
        MoneyFormatter.usd(minorUnits: choice.subtotalMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }
}
