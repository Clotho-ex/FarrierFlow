import Testing
@testable import FarrierFlow

@Suite("Subscription plan selection")
@MainActor
struct SubscriptionPlanSelectionModelTests {
    @Test
    func programmaticAnnualPreselectionDoesNotEmitButManualChangeDoes() {
        let annual = SubscriptionPlan(
            id: "annual-package",
            productID: SubscriptionProduct.yearly,
            kind: .annual,
            displayName: "Annual",
            localizedPrice: "$119.99",
            subscriptionPeriod: "year"
        )
        let monthly = SubscriptionPlan(
            id: "monthly-package",
            productID: SubscriptionProduct.monthly,
            kind: .monthly,
            displayName: "Monthly",
            localizedPrice: "$14.99",
            subscriptionPeriod: "month"
        )
        let analytics = AnalyticsSpy()
        let model = SubscriptionPlanSelectionModel()

        model.reconcile(with: [annual, monthly])
        #expect(model.selectedPlanID == annual.id)
        #expect(analytics.events.isEmpty)

        model.select(monthly, analyticsClient: analytics)
        model.select(monthly, analyticsClient: analytics)

        #expect(model.selectedPlanID == monthly.id)
        #expect(analytics.events == [.subscriptionPlanSelected(.monthly)])
    }
}
