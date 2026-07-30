import SwiftUI

struct InvoiceLineItemRow: View {
    @Environment(\.locale) private var locale
    let lineItem: InvoiceLineItemDetail

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.rowContent) {
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text(lineItem.horseName)
                    .font(Typography.recordTitle)
                Text(lineItem.serviceName)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount)
                .font(Typography.recordMetadata)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(amount)
    }

    private var amount: String {
        MoneyFormatter.usd(minorUnits: lineItem.amountMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }
}
