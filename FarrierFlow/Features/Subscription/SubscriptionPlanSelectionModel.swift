import Observation

@MainActor
@Observable
final class SubscriptionPlanSelectionModel {
    private(set) var selectedPlanID: String?

    func reconcile(with plans: [SubscriptionPlan]) {
        guard !plans.contains(where: { $0.id == selectedPlanID }) else { return }
        selectedPlanID = plans.first(where: { $0.kind == .annual })?.id
            ?? plans.first?.id
    }

    func select(
        _ plan: SubscriptionPlan,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) {
        guard selectedPlanID != plan.id else { return }
        selectedPlanID = plan.id
        analyticsClient.track(.subscriptionPlanSelected(plan.kind.analyticsPlan))
    }
}
