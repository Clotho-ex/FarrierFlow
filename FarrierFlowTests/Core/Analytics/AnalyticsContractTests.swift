import SwiftUI
import Testing
@testable import FarrierFlow

@Suite("Analytics contract")
struct AnalyticsContractTests {
    @Test
    @MainActor
    func everyEventMapsToOneStableProviderNameAndApprovedProperties() {
        let catalog: [(AnalyticsEvent, String, [String: String])] = [
            (.appFirstOpened, "app_first_opened", [:]),
            (.appSessionStarted, "app_session_started", [:]),
            (.onboardingStarted, "onboarding_started", [:]),
            (.onboardingBriefingCompleted, "onboarding_briefing_completed", [:]),
            (.businessSetupCompleted, "business_setup_completed", [:]),
            (.onboardingCompleted, "onboarding_completed", [:]),
            (.paywallViewed, "paywall_viewed", [:]),
            (
                .subscriptionPlanSelected(.monthly),
                "subscription_plan_selected",
                ["plan": "monthly"]
            ),
            (
                .subscriptionPurchaseStarted(.annual),
                "subscription_purchase_started",
                ["plan": "annual"]
            ),
            (
                .subscriptionPurchaseCompleted(.monthly),
                "subscription_purchase_completed",
                ["plan": "monthly"]
            ),
            (
                .subscriptionPurchaseCancelled(.annual),
                "subscription_purchase_cancelled",
                ["plan": "annual"]
            ),
            (.subscriptionRestoreCompleted, "subscription_restore_completed", [:]),
            (.clientCreated, "client_created", [:]),
            (.horseCreated, "horse_created", [:]),
            (.serviceCreated, "service_created", [:]),
            (.serviceLocationCreated, "service_location_created", [:]),
            (.appointmentCreated, "appointment_created", [:]),
            (.visitStarted, "visit_started", [:]),
            (.visitCompleted, "visit_completed", [:]),
            (.invoiceCreated, "invoice_created", [:]),
            (.invoiceShared, "invoice_shared", [:]),
            (.invoiceMarkedPaid, "invoice_marked_paid", [:]),
            (.nextAppointmentCreated, "next_appointment_created", [:]),
        ]

        let names = catalog.map { $0.1 }
        #expect(names.count == Set(names).count)
        var captures: [(String, [String: Any]?)] = []
        let client = PostHogAnalyticsClient { name, properties in
            captures.append((name, properties))
        }
        for (event, expectedName, expectedProperties) in catalog {
            captures.removeAll()
            client.track(event)
            #expect(captures.count == 1)
            #expect(captures[0].0 == expectedName)
            let properties = captures[0].1?.compactMapValues { $0 as? String } ?? [:]
            #expect(properties == expectedProperties)
            #expect(captures[0].1?["$geoip_disable"] as? Bool == true)
            #expect(captures[0].1?.count == expectedProperties.count + 1)
        }
    }

    @Test(arguments: [AnalyticsSubscriptionPlan.monthly, .annual])
    @MainActor
    func subscriptionPlansMapToTheOnlyApprovedProperty(
        plan: AnalyticsSubscriptionPlan
    ) {
        var captures: [[String: Any]?] = []
        let client = PostHogAnalyticsClient { _, properties in
            captures.append(properties)
        }

        client.track(.subscriptionPlanSelected(plan))
        client.track(.subscriptionPurchaseStarted(plan))
        client.track(.subscriptionPurchaseCompleted(plan))
        client.track(.subscriptionPurchaseCancelled(plan))

        #expect(captures.count == 4)
        for properties in captures {
            #expect(properties?["plan"] as? String == plan.rawValue)
            #expect(properties?["$geoip_disable"] as? Bool == true)
            #expect(properties?.count == 2)
        }
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
