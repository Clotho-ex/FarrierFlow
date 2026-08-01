import SwiftUI

struct InvoiceLineItemRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    let lineItem: InvoiceLineItemDetail

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    lineDescription
                    amountText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(
                    alignment: .firstTextBaseline,
                    spacing: SpacingTokens.rowContent
                ) {
                    lineDescription
                    Spacer()
                    amountText
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(amount)
    }

    private var lineDescription: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(lineItem.horseName)
                .font(Typography.recordTitle)
            Text(lineItem.serviceName)
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
        }
    }

    private var amountText: some View {
        Text(amount)
            .font(Typography.recordMetadata)
    }

    private var amount: String {
        MoneyFormatter.usd(minorUnits: lineItem.amountMinorUnits, locale: locale)
            ?? String(localized: "Unavailable", locale: locale)
    }

    private var accessibilityLabel: String {
        String(
            localized: "\(lineItem.horseName), \(lineItem.serviceName)",
            locale: locale
        )
    }
}
