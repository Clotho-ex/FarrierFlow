import SwiftUI

struct VisitHorseResultRow: View {
    let horse: VisitHorseResult

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(horse.horseName)
                .font(Typography.recordTitle)
            Text(horse.outcome.localizedTitle)
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
            if let workNotes = horse.workNotes {
                LabeledContent("Work Notes", value: workNotes)
                    .font(Typography.recordMetadata)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
