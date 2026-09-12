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
