import SwiftUI

struct InvoiceVisitSelectionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    let choice: InvoiceVisitChoice
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            if dynamicTypeSize.isAccessibilitySize {
                selectionAndVisit(includesSubtotal: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: SpacingTokens.rowContent) {
                    selectionAndVisit(includesSubtotal: false)
                    Spacer()
                    subtotalText
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Includes all eligible recorded work for this client.")
    }

    private func selectionAndVisit(includesSubtotal: Bool) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.rowContent) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text(
                    choice.visitDate,
                    format: .dateTime.month(.abbreviated).day().year()
                )
                .font(Typography.recordTitle)
                Text(choice.serviceLocationName)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
                if includesSubtotal {
                    subtotalText
                }
            }
        }
    }

    private var subtotalText: some View {
        Text(subtotal)
            .font(Typography.recordMetadata)
            .foregroundStyle(.secondary)
    }

    private var accessibilityLabel: String {
        let date = choice.visitDate.formatted(
            .dateTime.month(.abbreviated).day().year().locale(locale)
        )
        return String(
            localized: "Visit on \(date), \(choice.serviceLocationName), \(subtotal)",
            locale: locale
        )
    }

    private var subtotal: String {
        MoneyFormatter.usd(minorUnits: choice.subtotalMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }
}
