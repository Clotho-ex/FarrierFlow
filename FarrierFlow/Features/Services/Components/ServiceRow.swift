import SwiftUI

struct ServiceRow: View {
    @Environment(\.locale) private var locale
    let service: ServiceDetailSnapshot

    private var amount: String {
        MoneyFormatter.currency(
            minorUnits: service.defaultAmountMinorUnits,
            currencyCode: service.currencyCode,
            locale: locale
        ) ?? String(localized: "Unavailable", locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(service.name)
                .font(Typography.recordTitle)
            Text(amount)
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(service.isArchived ? "Archived" : "Active")
        .accessibilityIdentifier("service-row-\(service.name)")
    }
}
