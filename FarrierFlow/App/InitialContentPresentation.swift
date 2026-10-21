import SwiftUI
import UIKit

extension EnvironmentValues {
    @Entry var appStartupReady = true
}

/// Starts nonessential services after the initial local content has had a frame to present.
struct InitialContentPresentation: UIViewRepresentable {
    let presented: () -> Void

    func makeUIView(context: Context) -> PresentationView {
        PresentationView(presented: presented)
    }

    func updateUIView(_ uiView: PresentationView, context: Context) { }

    static func dismantleUIView(_ uiView: PresentationView, coordinator: ()) {
        uiView.stop()
    }

    final class PresentationView: UIView {
        private let presented: () -> Void
        private var displayLink: CADisplayLink?
        private var hasObservedFrame = false
        private var hasPresented = false

        init(presented: @escaping () -> Void) {
            self.presented = presented
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { return nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            stop()
            guard window != nil, !hasPresented else { return }
            hasObservedFrame = false
            let link = CADisplayLink(target: DisplayLinkTarget(view: self), selector: #selector(DisplayLinkTarget.tick))
            displayLink = link
            link.add(to: .main, forMode: .common)
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        fileprivate func tick() {
            // Display-link callbacks precede rendering. The second tick lets the first frame finish.
            guard hasObservedFrame else {
                hasObservedFrame = true
                return
            }
            stop()
            hasPresented = true
            presented()
        }
    }

    private final class DisplayLinkTarget: NSObject {
        weak var view: PresentationView?

        init(view: PresentationView) { self.view = view }

        @objc func tick() { view?.tick() }
    }
}
