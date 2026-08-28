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

nonisolated struct SubscriptionPlan: Sendable, Equatable, Identifiable {
    let id: String
    let productID: String
    let kind: SubscriptionPlanKind
    let displayName: String
    let localizedPrice: String
    let subscriptionPeriod: String
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
