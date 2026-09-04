import Foundation

@MainActor
protocol SubscriptionClient: Sendable {
    func customerInfo() async throws -> SubscriptionCustomerSnapshot
    func offerings() async throws -> [SubscriptionPlan]
    func purchase(planID: String) async throws -> SubscriptionPurchaseResult
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot
    func customerInfoUpdates() async -> AsyncStream<SubscriptionCustomerSnapshot>
}

nonisolated struct SubscriptionCustomerSnapshot: Sendable, Equatable {
    let hasActiveProEntitlement: Bool
}

nonisolated enum SubscriptionCustomerRules {
    static func snapshot(activeEntitlementIDs: Set<String>) -> SubscriptionCustomerSnapshot {
        .init(hasActiveProEntitlement: activeEntitlementIDs.contains(SubscriptionProduct.proEntitlement))
    }
}

nonisolated enum SubscriptionPlanKind: Sendable, Equatable {
    case monthly
    case annual
}

nonisolated enum SubscriptionTrialUnit: Sendable, Equatable {
    case day
    case week
    case month
    case year
}

nonisolated struct SubscriptionTrial: Sendable, Equatable {
    let duration: Int
    let unit: SubscriptionTrialUnit

    var localizedCallout: LocalizedStringResource {
        switch unit {
        case .day:
            "\(duration) days free"
        case .week:
            "\(duration) weeks free"
        case .month:
            "\(duration) months free"
        case .year:
            "\(duration) years free"
        }
    }
}

nonisolated struct SubscriptionPlan: Sendable, Equatable, Identifiable {
    let id: String
    let productID: String
    let kind: SubscriptionPlanKind
    let displayName: String
    let localizedPrice: String
    let localizedMonthlyEquivalent: String?
    let price: Decimal?
    let currencyCode: String?
    let subscriptionPeriod: String
    let introductoryTrial: SubscriptionTrial?

    init(
        id: String,
        productID: String,
        kind: SubscriptionPlanKind,
        displayName: String,
        localizedPrice: String,
        localizedMonthlyEquivalent: String? = nil,
        price: Decimal? = nil,
        currencyCode: String? = nil,
        subscriptionPeriod: String,
        introductoryTrial: SubscriptionTrial? = nil
    ) {
        self.id = id
        self.productID = productID
        self.kind = kind
        self.displayName = displayName
        self.localizedPrice = localizedPrice
        self.localizedMonthlyEquivalent = localizedMonthlyEquivalent
        self.price = price
        self.currencyCode = currencyCode
        self.subscriptionPeriod = subscriptionPeriod
        self.introductoryTrial = introductoryTrial
    }
}

nonisolated enum SubscriptionSavingsRules {
    static func annualSavingsPercentage(
        monthly: SubscriptionPlan,
        annual: SubscriptionPlan
    ) -> Int? {
        guard
            monthly.kind == .monthly,
            annual.kind == .annual,
            let monthlyPrice = monthly.price,
            let annualPrice = annual.price,
            monthlyPrice > 0,
            annualPrice > 0,
            let monthlyCurrency = monthly.currencyCode,
            monthlyCurrency == annual.currencyCode
        else {
            return nil
        }

        let annualizedMonthlyPrice = monthlyPrice * 12
        guard annualPrice < annualizedMonthlyPrice else { return nil }

        let savings = ((annualizedMonthlyPrice - annualPrice) / annualizedMonthlyPrice) * 100
        return Int(NSDecimalNumber(decimal: savings).doubleValue.rounded())
    }
}

nonisolated enum OnboardingSubscriptionDecisionRules {
    static func purchasePlanID(
        selectedPlanID: String?,
        availablePlans: [SubscriptionPlan]
    ) -> String? {
        guard
            let selectedPlanID,
            availablePlans.contains(where: { $0.id == selectedPlanID })
        else {
            return nil
        }
        return selectedPlanID
    }
}

nonisolated enum SubscriptionPurchaseCopy {
    static func actionTitle(
        for plan: SubscriptionPlan
    ) -> LocalizedStringResource {
        guard let trial = plan.introductoryTrial else {
            return "Subscribe"
        }
        switch trial.unit {
        case .day:
            return "Start \(trial.duration)-Day Free Trial"
        case .week:
            return "Start \(trial.duration)-Week Free Trial"
        case .month:
            return "Start \(trial.duration)-Month Free Trial"
        case .year:
            return "Start \(trial.duration)-Year Free Trial"
        }
    }

    static func disclosure(
        for plan: SubscriptionPlan
    ) -> LocalizedStringResource {
        if let trial = plan.introductoryTrial {
            return "\(trial.localizedCallout), then \(plan.localizedPrice)/\(plan.subscriptionPeriod). Cancel anytime."
        }
        return "\(plan.localizedPrice)/\(plan.subscriptionPeriod). Renews automatically. Cancel anytime."
    }
}

nonisolated struct SubscriptionPurchaseResult: Sendable, Equatable {
    let customer: SubscriptionCustomerSnapshot
    let wasCancelled: Bool
}

nonisolated enum SubscriptionPlanValidationError: Error, Equatable {
    case invalidOffering
}

nonisolated enum SubscriptionPlanRules {
    static func validated(_ plans: [SubscriptionPlan]) throws -> [SubscriptionPlan] {
        guard plans.count == 2 else {
            throw SubscriptionPlanValidationError.invalidOffering
        }
        let monthly = plans.filter {
            $0.kind == .monthly && $0.productID == SubscriptionProduct.monthly
        }
        let annual = plans.filter {
            $0.kind == .annual && $0.productID == SubscriptionProduct.yearly
        }
        guard monthly.count == 1, annual.count == 1 else {
            throw SubscriptionPlanValidationError.invalidOffering
        }
        return [annual[0], monthly[0]]
    }
}

@MainActor
struct UnavailableSubscriptionClient: SubscriptionClient {
    struct UnavailableError: Error { }

    func customerInfo() async throws -> SubscriptionCustomerSnapshot { throw UnavailableError() }
    func offerings() async throws -> [SubscriptionPlan] { throw UnavailableError() }
    func purchase(planID: String) async throws -> SubscriptionPurchaseResult { throw UnavailableError() }
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot { throw UnavailableError() }
    func customerInfoUpdates() async -> AsyncStream<SubscriptionCustomerSnapshot> {
        AsyncStream { $0.finish() }
    }
}
