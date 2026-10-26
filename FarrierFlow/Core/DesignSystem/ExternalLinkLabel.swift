import SwiftUI

struct ExternalLinkLabel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: SpacingTokens.compact) {
            content
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: SpacingTokens.compact)
            Image(systemName: "arrow.up.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityHidden(true)
        }
    }
}
