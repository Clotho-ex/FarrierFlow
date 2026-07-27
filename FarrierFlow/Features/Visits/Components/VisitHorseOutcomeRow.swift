import SwiftData
import SwiftUI

struct VisitHorseOutcomeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let horse: VisitHorseDraft
    let selectableOutcomes: [VisitOutcome]
    @Binding var workNotes: String
    @FocusState.Binding var focusedWorkNotesID: PersistentIdentifier?
    let onOutcomeSelected: (VisitOutcome) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    Text("Outcome")
                        .font(Typography.recordMetadata)
                        .foregroundStyle(.secondary)
                    outcomePicker
                        .labelsHidden()
                        .pickerStyle(.inline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                outcomePicker
            }
        }
        .accessibilityLabel("\(horse.horseName) Outcome")
        .accessibilityValue(Text(horse.outcome.localizedTitle))
        .accessibilityIdentifier("visit-outcome-\(horse.horseName)")

        if horse.outcome == .serviced {
            VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                Text("Work Notes")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
                TextEditor(text: $workNotes)
                    .frame(minHeight: 88)
                    .focused($focusedWorkNotesID, equals: horse.id)
                    .accessibilityLabel("Work Notes")
                    .accessibilityIdentifier("visit-work-notes-\(horse.horseName)")
            }
        }
    }

    private var outcomePicker: some View {
        Picker(
            "Outcome",
            selection: Binding(
                get: { horse.outcome },
                set: { onOutcomeSelected($0) }
            )
        ) {
            ForEach(selectableOutcomes, id: \.self) { outcome in
                Text(outcome.localizedTitle)
                    .tag(outcome)
            }
        }
    }
}
