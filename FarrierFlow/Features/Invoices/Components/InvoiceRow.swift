import SwiftUI

struct InvoiceRow: View {
    @Environment(\.locale) private var locale
    let summary: InvoiceSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text("Invoice \(summary.number)")
                    .font(Typography.recordTitle)
                Text(summary.clientName)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
                Text(summary.invoiceDate, format: .dateTime.month(.abbreviated).day().year())
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: SpacingTokens.rowContent)
            VStack(alignment: .trailing, spacing: SpacingTokens.rowContent) {
                Text(formattedTotal)
                    .font(Typography.recordTitle)
                Text(statusText)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Invoice \(summary.number), \(summary.clientName)")
        .accessibilityValue("\(formattedTotal), \(statusText)")
        .accessibilityIdentifier("invoice-row-\(summary.number)")
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
