import SwiftUI

private struct RollingStateText<Value: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: value)
    }
}

extension View {
    func rollingStateText(value: some Hashable) -> some View {
        modifier(RollingStateText(value: value))
    }
}
