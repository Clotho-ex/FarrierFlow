import Foundation
import PostHog

@MainActor
final class PostHogAnalyticsClient: AnalyticsClient {
    typealias Capture = (String, [String: Any]?) -> Void

    private let capture: Capture

    init(configuration: PostHogAnalyticsConfiguration) {
        let sdkConfiguration = Self.sdkConfiguration(for: configuration)
        PostHogSDK.shared.setup(sdkConfiguration)
        capture = { event, properties in
            PostHogSDK.shared.capture(event, properties: properties)
        }
    }

    init(capture: @escaping Capture) {
        self.capture = capture
    }

    convenience init(_ capture: @escaping Capture) {
        self.init(capture: capture)
    }

    func track(_ event: AnalyticsEvent) {
        let providerEvent = ProviderEvent(event)
        capture(providerEvent.name, providerEvent.properties)
    }

    static func sdkConfiguration(
        for configuration: PostHogAnalyticsConfiguration
    ) -> PostHogConfig {
        let config = PostHogConfig(
            projectToken: configuration.projectToken,
            host: configuration.host.absoluteString
        )
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.captureElementInteractions = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.setDefaultPersonProperties = false
        config.personProfiles = .never
        config.sessionReplay = false
        config.surveys = false
        config.errorTrackingConfig.autoCapture = false
        config.debug = false
        config.rageClickConfig.enabled = false
        config.tracingHeaders = nil
        return config
    }
}

private struct ProviderEvent {
    let name: String
    let properties: [String: Any]

    init(_ event: AnalyticsEvent) {
        switch event {
        case .appFirstOpened:
            self.init(name: "app_first_opened")
        case .appSessionStarted:
            self.init(name: "app_session_started")
        case .onboardingStarted:
            self.init(name: "onboarding_started")
        case .onboardingBriefingCompleted:
            self.init(name: "onboarding_briefing_completed")
        case .businessSetupCompleted:
            self.init(name: "business_setup_completed")
        case .onboardingCompleted:
            self.init(name: "onboarding_completed")
        case .paywallViewed:
            self.init(name: "paywall_viewed")
        case .subscriptionPlanSelected(let plan):
            self.init(name: "subscription_plan_selected", plan: plan)
        case .subscriptionPurchaseStarted(let plan):
            self.init(name: "subscription_purchase_started", plan: plan)
        case .subscriptionPurchaseCompleted(let plan):
            self.init(name: "subscription_purchase_completed", plan: plan)
        case .subscriptionPurchaseCancelled(let plan):
            self.init(name: "subscription_purchase_cancelled", plan: plan)
        case .subscriptionRestoreCompleted:
            self.init(name: "subscription_restore_completed")
        case .clientCreated:
            self.init(name: "client_created")
        case .horseCreated:
            self.init(name: "horse_created")
        case .serviceCreated:
            self.init(name: "service_created")
        case .serviceLocationCreated:
            self.init(name: "service_location_created")
        case .appointmentCreated:
            self.init(name: "appointment_created")
        case .visitStarted:
            self.init(name: "visit_started")
        case .visitCompleted:
            self.init(name: "visit_completed")
        case .invoiceCreated:
            self.init(name: "invoice_created")
        case .invoiceShared:
            self.init(name: "invoice_shared")
        case .invoiceMarkedPaid:
            self.init(name: "invoice_marked_paid")
        case .nextAppointmentCreated:
            self.init(name: "next_appointment_created")
        }
    }

    private init(name: String, properties: [String: Any] = [:]) {
        self.name = name
        self.properties = properties.merging(["$geoip_disable": true]) { approved, _ in
            approved
        }
    }

    private init(name: String, plan: AnalyticsSubscriptionPlan) {
        self.init(name: name, properties: ["plan": plan.rawValue])
    }
}
