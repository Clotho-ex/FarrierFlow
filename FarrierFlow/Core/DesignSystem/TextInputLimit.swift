import SwiftUI

extension View {
    func inputLimit(_ text: Binding<String>, maximum: Int, rejectOverflow: Bool = false) -> some View {
        modifier(TextInputLimit(text: text, maximum: maximum, rejectOverflow: rejectOverflow))
    }
}

private struct TextInputLimit: ViewModifier {
    @Binding var text: String
    let maximum: Int
    let rejectOverflow: Bool
    @State private var reachedLimit = false

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tight) {
            content
            if reachedLimit || text.count >= maximum {
                Text("Maximum \(maximum) characters.")
                    .font(.footnote)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("input-limit-message")
            }
        }
        .onChange(of: text) { previous, value in
            guard value.count > maximum else { return }
            reachedLimit = true
            text = InputLimits.accepting(value, previous: previous, maximum: maximum, rejectOverflow: rejectOverflow)
        }
    }
}
