import SwiftUI

extension View {
    func farrierFlowPrimaryAction() -> some View {
        modifier(FarrierFlowPrimaryActionModifier())
    }

    func farrierFlowBorderedAction(tint: Color = ColorTokens.textSecondary) -> some View {
        buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(tint)
            .frame(maxWidth: .infinity, minHeight: SpacingTokens.minimumTouchTarget)
            .contentShape(Rectangle())
    }

    func farrierFlowScreenBackground() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background.ignoresSafeArea())
    }

    func farrierFlowScrollBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(ColorTokens.background)
    }
}

private struct FarrierFlowPrimaryActionModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.brandPrimary)
            .foregroundStyle(isEnabled ? ColorTokens.onBrand : ColorTokens.textSecondary)
    }
}
