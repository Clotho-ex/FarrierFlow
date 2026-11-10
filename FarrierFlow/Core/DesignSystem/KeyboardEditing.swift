import SwiftUI
import UIKit

private struct FocusedInputID<Value: Hashable>: Hashable {
    let value: Value
}

private struct FocusedInputVisibility<Value: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let focus: Value?

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: focus) { _, _ in reveal(using: proxy) }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { _ in
                    reveal(using: proxy)
                }
        }
    }

    private func reveal(using proxy: ScrollViewProxy) {
        guard let focus else { return }
        // Wait for the keyboard safe area and accessory to finish their layout.
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                proxy.scrollTo(FocusedInputID(value: focus), anchor: .center)
            }
        }
    }
}

private struct KeyboardDoneAccessory: ViewModifier {
    let isFocused: Bool
    let identifier: String
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // Keep the native glass button clear of the floating keyboard’s rounded edge.
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                if isFocused {
                    HStack {
                        Spacer()
                        doneButton
                            .buttonStyle(.glass)
                            .controlSize(.large)
                    }
                    .padding(.horizontal, SpacingTokens.standard)
                    .padding(.vertical, SpacingTokens.compact)
                }
            }
        } else {
            content.toolbar {
                if isFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        doneButton
                    }
                }
            }
        }
    }

    private var doneButton: some View {
        Button("Done", action: dismiss)
            .font(.subheadline.weight(.semibold))
            .tint(.primary)
            .accessibilityHint("Dismisses the keyboard without saving")
            .accessibilityIdentifier(identifier)
    }
}

extension View {
    func focusedInputAnchor(_ value: some Hashable) -> some View {
        id(FocusedInputID(value: value))
    }

    func keepFocusedInputVisible(_ focus: (some Hashable)?) -> some View {
        modifier(FocusedInputVisibility(focus: focus))
    }

    func keyboardDoneAccessory(isFocused: Bool, identifier: String, dismiss: @escaping () -> Void) -> some View {
        modifier(KeyboardDoneAccessory(isFocused: isFocused, identifier: identifier, dismiss: dismiss))
    }
}
