import SwiftUI

struct BusinessOverviewSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    let model: BusinessOverviewModel
    let retry: () -> Void
    let open: (BusinessOverviewRoute) -> Void

    var body: some View {
        Section("Business Overview") {
            if let summary = model.summary {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.related))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: SpacingTokens.related))
                layout {
                    Button {
                        open(.outstandingInvoices)
                    } label: {
                        BusinessMetricRow(
                            title: "Outstanding",
                            value: MoneyFormatter.currency(
                                minorUnits: summary.outstandingMinorUnits,
                                currencyCode: summary.currencyCode,
                                locale: locale,
                                showsZeroAsComplimentary: false
                            ) ?? String(localized: "Unavailable", locale: locale),
                            detail: String(localized: "businessOverview.unpaidInvoices", defaultValue: "\(summary.unpaidInvoiceCount) unpaid invoices", locale: locale)
                        )
                    }
                    .accessibilityHint("Opens unpaid invoices")
                    .accessibilityIdentifier("business-outstanding")

                    Button {
                        open(.completedVisits(summary.month))
                    } label: {
                        BusinessMetricRow(
                            title: "Completed Visits",
                            value: summary.completedVisitCount.formatted(.number.locale(locale)),
                            detail: String(localized: "This Month", locale: locale)
                        )
                    }
                    .accessibilityHint("Opens completed visits for this month")
                    .accessibilityIdentifier("business-completed-visits")
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if model.loadFailed {
                Text("FarrierFlow couldn’t load your business overview. Review your invoices and business profile, or try again.")
                    .foregroundStyle(ColorTokens.textSecondary)
                Button("Retry", action: retry)
            } else {
                ProgressView("Loading Business Overview…")
            }
        }
        .listRowBackground(ColorTokens.surface)
    }
}

private struct BusinessMetricRow: View {
    let title: LocalizedStringResource
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tight) {
            Text(title)
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textPrimary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: SpacingTokens.minimumTouchTarget, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(SpacingTokens.standard)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.surface, in: .rect(cornerRadius: SpacingTokens.standard))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
