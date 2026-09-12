nonisolated enum SubscriptionProduct {
    static let proEntitlement = "pro"
    static let monthly = "com.farrierflow.yusufcan.FarrierFlow.pro.monthly"
    static let yearly = "com.farrierflow.yusufcan.FarrierFlow.pro.yearly"
    static let identifiers: Set<String> = [monthly, yearly]
    static let orderedIdentifiers = [yearly, monthly]

    static func kind(for productID: String) -> SubscriptionPlanKind? {
        switch productID {
        case monthly: .monthly
        case yearly: .annual
        default: nil
        }
    }
}

nonisolated extension SubscriptionPlanKind {
    var analyticsPlan: AnalyticsSubscriptionPlan {
        switch self {
        case .monthly: .monthly
        case .annual: .annual
        }
    }
}
