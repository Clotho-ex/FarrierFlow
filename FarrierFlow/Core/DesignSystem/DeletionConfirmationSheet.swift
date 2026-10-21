import SwiftUI

struct DeletionConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat?

    let title: LocalizedStringKey
    private let message: Text
    let confirmationTitle: LocalizedStringKey
    let accessibilityPrefix: String
    let onConfirm: () -> Void

    init(
        title: LocalizedStringKey, message: LocalizedStringKey,
        confirmationTitle: LocalizedStringKey, accessibilityPrefix: String,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = Text(message)
        self.confirmationTitle = confirmationTitle
        self.accessibilityPrefix = accessibilityPrefix
        self.onConfirm = onConfirm
    }

    init(
        title: LocalizedStringKey, warning: LocalizedStringResource,
        confirmationTitle: LocalizedStringKey, accessibilityPrefix: String,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = Text(warning)
        self.confirmationTitle = confirmationTitle
        self.accessibilityPrefix = accessibilityPrefix
        self.onConfirm = onConfirm
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.recordSection) {
                VStack(spacing: SpacingTokens.related) {
                    Image(systemName: "trash")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ColorTokens.destructive)
                        .frame(
                            width: SpacingTokens.hero,
                            height: SpacingTokens.hero
                        )
                        .background(ColorTokens.destructiveTint, in: Circle())
                        .accessibilityHidden(true)

                    VStack(spacing: SpacingTokens.compact) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                        message
                            .font(.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: SpacingTokens.related) {
                    Button(role: .destructive) {
                        onConfirm()
                        dismiss()
                    } label: {
                        DeletionActionLabel(
                            title: confirmationTitle,
                            systemImage: "trash"
                        )
                    }
                    .farrierFlowBorderedAction(tint: ColorTokens.destructive)
                    .accessibilityIdentifier("\(accessibilityPrefix)-confirmation")

                    Button(role: .cancel) { dismiss() } label: {
                        DeletionActionLabel(
                            title: "Cancel",
                            systemImage: "xmark"
                        )
                    }
                    .farrierFlowBorderedAction()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, SpacingTokens.section)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { height in
                contentHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .farrierFlowScreenBackground()
        .presentationDetents([contentHeight.map(PresentationDetent.height) ?? .medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("\(accessibilityPrefix)-sheet")
    }
}

private struct DeletionActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: SpacingTokens.compact) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(
                    width: SpacingTokens.section,
                    height: SpacingTokens.section
                )
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }
}
