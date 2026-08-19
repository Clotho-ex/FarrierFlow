protocol SubscriptionEntitlementSource: Sendable {
    func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool
    func updates(productIDs: Set<String>) async -> AsyncStream<Void>
}
