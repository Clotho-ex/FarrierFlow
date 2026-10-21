import SwiftData
import SwiftUI

extension View {
    func recordDeletionSheet(
        _ target: RecordDeletionTarget,
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        confirmationTitle: LocalizedStringKey,
        accessibilityPrefix: String,
        alert: Binding<FeatureAlert?>,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(RecordDeletionPresentation(
            target: target, isPresented: isPresented, alert: alert, title: title,
            confirmationTitle: confirmationTitle, accessibilityPrefix: accessibilityPrefix,
            onDelete: onDelete
        ))
    }
}

private struct RecordDeletionPresentation: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(PhotographLibrary.self) private var library
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var controller = RecordDeletionController()
    @State private var confirmed: RecordDeletionImpact?

    let target: RecordDeletionTarget
    @Binding var isPresented: Bool
    @Binding var alert: FeatureAlert?
    let title: LocalizedStringKey
    let confirmationTitle: LocalizedStringKey
    let accessibilityPrefix: String
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .disabled(controller.isDeleting)
            .sheet(isPresented: $isPresented, onDismiss: performConfirmedDeletion) {
                Group {
                    if let impact = controller.impact {
                        DeletionConfirmationSheet(
                            title: title, warning: impact.warning,
                            confirmationTitle: confirmationTitle,
                            accessibilityPrefix: accessibilityPrefix
                        ) {
                            confirmed = impact
                        }
                    } else {
                        ProgressView("Loading…")
                            .presentationDetents([.medium])
                    }
                }
                .dynamicTypeSize(dynamicTypeSize)
                .task {
                    confirmed = nil
                    controller.prepare(target, in: context.container)
                    if controller.impact == nil { isPresented = false }
                }
            }
    }

    private func performConfirmedDeletion() {
        guard let impact = confirmed else {
            if let failure = controller.alert { alert = failure }
            return
        }
        confirmed = nil
        guard subscription.allowsMutations else { return }
        Task {
            if await controller.delete(impact, using: library) {
                onDelete()
            } else {
                alert = controller.alert
            }
        }
    }
}
