import SwiftUI

struct HorseHistoryRow: View {
    let entry: HorseHistoryEntry

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
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("horse-history-row-\(entry.horseName)")
    }
}
