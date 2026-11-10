import SwiftData
import SwiftUI

extension View {
    func recordDeletionConfirmation(
        _ target: RecordDeletionTarget,
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        confirmationTitle: LocalizedStringKey,
        accessibilityPrefix: String,
        alert: Binding<FeatureAlert?>,
        isDeleting: Binding<Bool> = .constant(false),
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(RecordDeletionPresentation(
            target: target, isPresented: isPresented, alert: alert, isDeleting: isDeleting, title: title,
            confirmationTitle: confirmationTitle, accessibilityPrefix: accessibilityPrefix,
            onDelete: onDelete
        ))
    }
}

private struct RecordDeletionPresentation: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(PhotographLibrary.self) private var library
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var controller = RecordDeletionController()

    let target: RecordDeletionTarget
    @Binding var isPresented: Bool
    @Binding var alert: FeatureAlert?
    @Binding var isDeleting: Bool
    let title: LocalizedStringKey
    let confirmationTitle: LocalizedStringKey
    let accessibilityPrefix: String
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .disabled(controller.isDeleting)
            .onChange(of: isPresented) { _, presented in
                if presented {
                    controller.prepare(target, in: context.container)
                    if controller.impact == nil {
                        isPresented = false
                        alert = controller.alert
                    }
                }
            }
            .alert(title, isPresented: confirmationIsPresented, presenting: controller.impact) { impact in
                Button(confirmationTitle, role: .destructive) {
                    performDeletion(impact)
                }
                .accessibilityIdentifier("\(accessibilityPrefix)-confirmation")
                Button("Cancel", role: .cancel) {}
            } message: { impact in
                Text(impact.warning)
            }
            .tint(.primary)
    }

    private var confirmationIsPresented: Binding<Bool> {
        Binding(
            get: { isPresented && controller.impact != nil },
            set: { isPresented = $0 }
        )
    }

    private func performDeletion(_ impact: RecordDeletionImpact) {
        guard subscription.allowsMutations, !controller.isDeleting else { return }
        isPresented = false
        isDeleting = true
        Task {
            defer { isDeleting = false }
            if await controller.delete(impact, using: library) {
                alert = nil
                onDelete()
            } else {
                alert = controller.alert
            }
        }
    }
}
