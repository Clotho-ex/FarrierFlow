nonisolated enum AnalyticsSubscriptionPlan: String, CaseIterable, Sendable {
    case monthly
    case annual
}

nonisolated enum AnalyticsEvent: Equatable, Sendable {
    case appFirstOpened
    case appSessionStarted
    case onboardingStarted
    case onboardingBriefingCompleted
    case businessSetupCompleted
    case onboardingCompleted
    case paywallViewed
    case subscriptionPlanSelected(AnalyticsSubscriptionPlan)
    case subscriptionPurchaseStarted(AnalyticsSubscriptionPlan)
    case subscriptionPurchaseCompleted(AnalyticsSubscriptionPlan)
    case subscriptionPurchaseCancelled(AnalyticsSubscriptionPlan)
    case subscriptionRestoreCompleted
    case clientCreated
    case horseCreated
    case serviceCreated
    case serviceLocationCreated
    case appointmentCreated
    case visitStarted
    case visitCompleted
    case invoiceCreated
    case invoiceShared
    case invoiceMarkedPaid
    case nextAppointmentCreated
}

nonisolated enum AnalyticsProviderProperty: Equatable, Sendable {
    case plan(AnalyticsSubscriptionPlan)

    var name: String {
        switch self {
        case .plan:
            "plan"
        }
    }

    var value: String {
        switch self {
        case .plan(let plan):
            plan.rawValue
        }
    }
}

/// Translation owned by a future provider adapter. Feature code tracks
/// `AnalyticsEvent` directly and does not consume this representation.
nonisolated struct AnalyticsProviderEvent: Equatable, Sendable {
    let name: String
    let properties: [AnalyticsProviderProperty]

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

    private init(
        name: String,
        properties: [AnalyticsProviderProperty] = []
    ) {
        self.name = name
        self.properties = properties
    }

    private init(name: String, plan: AnalyticsSubscriptionPlan) {
        self.init(name: name, properties: [.plan(plan)])
    }
}
