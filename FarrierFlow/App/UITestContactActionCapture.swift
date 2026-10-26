import SwiftUI

extension View {
    @ViewBuilder
    func uiTestContactActionCapture() -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FARRIERFLOW_UI_TEST_STORE"] != nil,
           ProcessInfo.processInfo.environment["FARRIERFLOW_UI_TEST_CAPTURE_CONTACT_ACTIONS"] == "1" {
            modifier(UITestContactActionCapture())
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if DEBUG
private struct UITestContactActionCapture: ViewModifier {
    @State private var lastURL: String = ""
    @State private var requestCount = 0

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                lastURL = url.absoluteString
                requestCount += 1
                return .handled
            })
            .overlay(alignment: .bottom) {
                if !lastURL.isEmpty {
                    // Expose dispatch to automation without altering fixture screenshots.
                    Text(verbatim: lastURL)
                        .font(.caption)
                        .padding(SpacingTokens.compact)
                        .foregroundStyle(.clear)
                        .accessibilityIdentifier("ui-test-contact-url")
                        .accessibilityValue(String(requestCount))
                        .allowsHitTesting(false)
                }
            }
    }
}
#endif
