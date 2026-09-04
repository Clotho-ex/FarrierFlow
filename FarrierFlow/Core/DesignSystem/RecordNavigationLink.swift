import SwiftUI

struct RecordNavigationLink<Label: View, Link: View>: View {
    private let label: Label
    private let link: Link

    init<Value: Hashable>(
        value: Value,
        @ViewBuilder label: () -> Label
    ) where Link == NavigationLink<Label, Never> {
        let content = label()
        self.label = content
        self.link = NavigationLink(value: value) { content }
    }

    init<Destination: View>(
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder label: () -> Label
    ) where Link == NavigationLink<Label, Destination> {
        let content = label()
        self.label = content
        self.link = NavigationLink(destination: destination) { content }
    }

    var body: some View {
        if #available(iOS 26, *) {
            link.navigationLinkIndicatorVisibility(.hidden)
        } else {
            // iOS 18 still draws List accessories despite the visibility modifier.
            // Keep the native link for activation and its accessibility representation.
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                .background { link.opacity(0).accessibilityHidden(true) }
                .accessibilityRepresentation { link }
        }
    }
}
