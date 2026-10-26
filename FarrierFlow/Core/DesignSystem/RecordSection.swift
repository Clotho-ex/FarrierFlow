import SwiftUI

/// Retains native list grouping while keeping category headings subordinate to records.
struct RecordSection<Content: View>: View {
    let title: Text
    @ViewBuilder let content: Content

    init(_ title: Text, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            title.recordSectionHeading()
        }
    }
}

extension View {
    func recordSectionHeading() -> some View {
        font(Typography.sectionHeading)
            .foregroundStyle(ColorTokens.textSecondary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}
