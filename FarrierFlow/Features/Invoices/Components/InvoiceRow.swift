import SwiftUI

struct InvoiceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    let summary: InvoiceSummary

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    invoiceIdentity
                    totalAndStatus
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(
                    alignment: .firstTextBaseline,
                    spacing: SpacingTokens.rowContent
                ) {
                    invoiceIdentity
                    Spacer(minLength: SpacingTokens.rowContent)
                    totalAndStatus
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(formattedTotal), \(statusText)")
        .accessibilityIdentifier("invoice-row-\(summary.number)")
    }

    private var invoiceIdentity: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text("Invoice \(summary.number)")
                .font(Typography.recordTitle)
            Text(summary.clientName)
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
            Text(
                summary.invoiceDate,
                format: .dateTime.month(.abbreviated).day().year()
            )
            .font(Typography.recordMetadata)
            .foregroundStyle(.secondary)
        }
    }

    private var totalAndStatus: some View {
        VStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
            spacing: SpacingTokens.rowContent
        ) {
            Text(formattedTotal)
                .font(Typography.recordTitle)
            Text(statusText)
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
        }
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

    private var statusText: String {
        summary.status == .paid ? String(localized: "Paid") : String(localized: "Unpaid")
    }
}
