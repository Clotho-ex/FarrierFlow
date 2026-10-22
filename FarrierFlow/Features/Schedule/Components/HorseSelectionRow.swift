import SwiftUI

struct HorseSelectionRow: View {
    let horse: Horse
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                HorseRow(horse: horse, context: .serviceLocationDetail)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        isSelected
                            ? ColorTokens.brandActionText
                            : ColorTokens.textSecondary
                    )
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Includes or removes this horse from the appointment")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
