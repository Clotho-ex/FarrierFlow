import SwiftUI

struct HorseHistoryRow: View {
    let entry: HorseHistoryEntry
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(entry.startedAt, format: .dateTime.month().day().year())
                .font(Typography.recordTitle)
            Text(entry.serviceLocationName)
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
            Text(entry.outcome.localizedTitle)
                .font(Typography.recordMetadata)
            if entry.hasWorkNotes {
                Text("Work Notes")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
            if entry.outcome == .serviced {
                if let workItemCount = entry.workItemCount {
                    Text(String(localized: "Services: \(workItemCount)"))
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Subtotal", value: subtotalText)
                    .font(Typography.recordMetadata)
                if entry.subtotal == .unavailable {
                    Text("No recorded services")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("horse-history-row-\(entry.horseName)")
    }

    private var subtotalText: String {
        switch entry.subtotal {
        case let .available(minorUnits):
            MoneyFormatter.usd(minorUnits: minorUnits, locale: locale)
                ?? String(localized: "Subtotal Unavailable", locale: locale)
        case .unavailable:
            String(localized: "Subtotal Unavailable", locale: locale)
        }
    }
}
