import SwiftData
import SwiftUI

struct VisitHorseOutcomeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let horse: VisitHorseDraft
    let selectableOutcomes: [VisitOutcome]
    let onOutcomeSelected: (VisitOutcome) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    Text("Work Outcome")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(ColorTokens.textSecondary)
                    outcomePicker
                        .labelsHidden()
                        .pickerStyle(.inline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                outcomePicker
            }
        }
        .accessibilityLabel("\(horse.horseName) Work Outcome")
        .accessibilityValue(Text(horse.outcome.localizedTitle))
        .accessibilityIdentifier("visit-outcome-\(horse.horseName)")

    }

    private var outcomePicker: some View {
        Picker(
            "Work Outcome",
            selection: Binding(
                get: { horse.outcome },
                set: { onOutcomeSelected($0) }
            )
        ) {
            ForEach(selectableOutcomes, id: \.self) { outcome in
                Group {
                    if outcome == .pending { Text("Choose") }
                    else { Text(outcome.localizedTitle) }
                }
                .tag(outcome)
            }
        }
    }
}
