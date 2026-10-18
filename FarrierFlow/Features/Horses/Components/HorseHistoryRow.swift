import SwiftUI

struct HorseHistoryRow: View {
    let entry: HorseHistoryEntry
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.standard) {
            VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                historyHeader

                Text(entry.serviceLocationName)
                    .font(.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            if entry.outcome == .serviced {
                serviceSummary
            }

            Divider()

            HStack(spacing: SpacingTokens.compact) {
                Text("View Visit")
                    .font(.body.weight(.medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer(minLength: SpacingTokens.compact)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: SpacingTokens.minimumTouchTarget)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the visit details")
        .accessibilityIdentifier("horse-history-row-\(entry.horseName)")
    }

    @ViewBuilder
    private var historyHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                visitDate
                outcomePill
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.related) {
                visitDate
                Spacer(minLength: SpacingTokens.compact)
                outcomePill
            }
        }
    }

    private var visitDate: some View {
        Text(entry.startedAt, format: .dateTime.month().day().year())
            .font(.title3.weight(.semibold))
            .foregroundStyle(ColorTokens.textPrimary)
    }

    private var outcomePill: some View {
        Text(entry.outcome.localizedTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(outcomeTone.emphasis)
            .padding(.horizontal, SpacingTokens.compact)
            .padding(.vertical, SpacingTokens.tight)
            .background(outcomeTone.background, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var serviceSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: SpacingTokens.tight) {
                serviceCountText
                Text(subtotalText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.related) {
                serviceCountText
                Spacer(minLength: SpacingTokens.compact)
                Text(subtotalText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }

    private var serviceCountText: some View {
        Text(serviceCountLabel)
            .font(.body)
            .foregroundStyle(ColorTokens.textSecondary)
    }

    private var serviceCountLabel: LocalizedStringKey {
        guard let workItemCount = entry.workItemCount else {
            return "Services unavailable"
        }
        return workItemCount == 1
            ? "1 service"
            : "\(workItemCount) services"
    }

    private var outcomeTone: StatusTone {
        entry.outcome == .serviced ? .success : .neutral
    }

    private var subtotalText: String {
        switch entry.subtotal {
        case let .available(minorUnits):
            MoneyFormatter.currency(
                minorUnits: minorUnits,
                currencyCode: entry.currencyCode,
                locale: locale
            )
                ?? String(localized: "Subtotal Unavailable", locale: locale)
        case .unavailable:
            String(localized: "Subtotal Unavailable", locale: locale)
        }
    }
}
