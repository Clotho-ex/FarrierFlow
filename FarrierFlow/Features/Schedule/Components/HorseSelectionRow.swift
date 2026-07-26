import SwiftUI

struct HorseSelectionRow: View {
    let horse: Horse
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                HorseRow(horse: horse)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ColorTokens.interactive)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
