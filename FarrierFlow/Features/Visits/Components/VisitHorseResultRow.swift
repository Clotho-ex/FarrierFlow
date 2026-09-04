import SwiftUI

struct VisitHorseResultRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let horse: VisitHorseResult

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(horse.horseName)
                .font(Typography.recordTitle)
            if dynamicTypeSize.isAccessibilitySize {
                outcomeText
                    .font(Typography.recordMetadata)
            }
            if let workNotes = horse.workNotes {
                LabeledContent("Work Notes", value: workNotes)
                    .font(Typography.recordMetadata)
            }
        }
        .accessibilityElement(children: .combine)
        .badge(dynamicTypeSize.isAccessibilitySize ? nil : outcomeText)
    }

    private var outcomeText: Text {
        Text(horse.outcome.localizedTitle)
            .foregroundStyle(horse.outcome == .serviced ? ColorTokens.success : ColorTokens.textSecondary)
    }
}
