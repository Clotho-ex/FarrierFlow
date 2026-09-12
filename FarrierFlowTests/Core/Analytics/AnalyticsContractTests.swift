import SwiftUI
import Testing
@testable import FarrierFlow

@Suite("Analytics contract")
struct AnalyticsContractTests {
    @Test
    func everyEventMapsToOneStableProviderNameAndApprovedProperties() {
        let catalog: [(AnalyticsEvent, String, [AnalyticsProviderProperty])] = [
            (.appFirstOpened, "app_first_opened", []),
            (.appSessionStarted, "app_session_started", []),
            (.onboardingStarted, "onboarding_started", []),
            (.onboardingBriefingCompleted, "onboarding_briefing_completed", []),
            (.businessSetupCompleted, "business_setup_completed", []),
            (.onboardingCompleted, "onboarding_completed", []),
            (.paywallViewed, "paywall_viewed", []),
            (
                .subscriptionPlanSelected(.monthly),
                "subscription_plan_selected",
                [.plan(.monthly)]
            ),
            (
                .subscriptionPurchaseStarted(.annual),
                "subscription_purchase_started",
                [.plan(.annual)]
            ),
            (
                .subscriptionPurchaseCompleted(.monthly),
                "subscription_purchase_completed",
                [.plan(.monthly)]
            ),
            (
                .subscriptionPurchaseCancelled(.annual),
                "subscription_purchase_cancelled",
                [.plan(.annual)]
            ),
            (.subscriptionRestoreCompleted, "subscription_restore_completed", []),
            (.clientCreated, "client_created", []),
            (.horseCreated, "horse_created", []),
            (.serviceCreated, "service_created", []),
            (.serviceLocationCreated, "service_location_created", []),
            (.appointmentCreated, "appointment_created", []),
            (.visitStarted, "visit_started", []),
            (.visitCompleted, "visit_completed", []),
            (.invoiceCreated, "invoice_created", []),
            (.invoiceShared, "invoice_shared", []),
            (.invoiceMarkedPaid, "invoice_marked_paid", []),
            (.nextAppointmentCreated, "next_appointment_created", []),
        ]

        let names = catalog.map { $0.1 }
        #expect(names.count == Set(names).count)
        for (event, expectedName, expectedProperties) in catalog {
            let providerEvent = AnalyticsProviderEvent(event)
            #expect(providerEvent.name == expectedName)
            #expect(providerEvent.properties == expectedProperties)
        }
    }

    @Test(arguments: [AnalyticsSubscriptionPlan.monthly, .annual])
    func subscriptionPlansMapToTheOnlyApprovedProperty(
        plan: AnalyticsSubscriptionPlan
    ) {
        let property = AnalyticsProviderProperty.plan(plan)

        #expect(property.name == "plan")
        #expect(property.value == plan.rawValue)
        #expect(
            AnalyticsProviderEvent(.subscriptionPlanSelected(plan)).properties == [property]
        )
        #expect(
            AnalyticsProviderEvent(.subscriptionPurchaseStarted(plan)).properties == [property]
        )
        #expect(
            AnalyticsProviderEvent(.subscriptionPurchaseCompleted(plan)).properties == [property]
        )
        #expect(
            AnalyticsProviderEvent(.subscriptionPurchaseCancelled(plan)).properties == [property]
        )
    }

    @Test
    @MainActor
    func noOpClientAcceptsTheCompleteCatalog() {
        let client = NoOpAnalyticsClient()
        let events: [AnalyticsEvent] = [
            .appFirstOpened,
            .appSessionStarted,
            .onboardingStarted,
            .onboardingBriefingCompleted,
            .businessSetupCompleted,
            .onboardingCompleted,
            .paywallViewed,
            .subscriptionPlanSelected(.monthly),
            .subscriptionPurchaseStarted(.annual),
            .subscriptionPurchaseCompleted(.monthly),
            .subscriptionPurchaseCancelled(.annual),
            .subscriptionRestoreCompleted,
            .clientCreated,
            .horseCreated,
            .serviceCreated,
            .serviceLocationCreated,
            .appointmentCreated,
            .visitStarted,
            .visitCompleted,
            .invoiceCreated,
            .invoiceShared,
            .invoiceMarkedPaid,
            .nextAppointmentCreated,
        ]

        for event in events {
            client.track(event)
        }
    }

    @Test
    @MainActor
    func swiftUIEnvironmentDefaultsToNoOpAndAllowsInjection() {
        var values = EnvironmentValues()
        values.analyticsClient.track(.appSessionStarted)

        let analytics = AnalyticsSpy()
        values.analyticsClient = analytics
        values.analyticsClient.track(.clientCreated)

        #expect(analytics.events == [.clientCreated])
    }
}
