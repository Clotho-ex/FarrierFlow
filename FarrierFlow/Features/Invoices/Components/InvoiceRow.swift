import SwiftUI

struct InvoiceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    let summary: InvoiceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            invoiceIdentity
            Text(formattedTotal)
                .font(Typography.recordTitle)
            if dynamicTypeSize.isAccessibilitySize {
                Text(summary.status.displayName)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(summary.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            dynamicTypeSize.isAccessibilitySize
                ? "\(formattedTotal), \(summary.status.displayName)"
                : formattedTotal
        )
        .accessibilityIdentifier("invoice-row-\(summary.number)")
    }

    private var invoiceIdentity: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text("Invoice \(summary.number)")
                .font(Typography.recordTitle)
            Text(summary.clientName)
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
            Text(
                summary.invoiceDate,
                format: .dateTime.month(.abbreviated).day().year()
            )
            .font(Typography.recordMetadata)
            .foregroundStyle(ColorTokens.textSecondary)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityLabel: String {
        let date = summary.invoiceDate.formatted(
            .dateTime.month(.abbreviated).day().year().locale(locale)
        )
        return String(
            localized: "Invoice \(summary.number), \(summary.clientName), \(date)",
            locale: locale
        )
    }

    private var formattedTotal: String {
        switch summary.total {
        case .available(let amount):
            MoneyFormatter.usd(minorUnits: amount, locale: locale)
                ?? String(localized: "Unavailable", locale: locale)
        case .unavailable:
            String(localized: "Unavailable", locale: locale)
        }
    }
}
