nonisolated enum SubscriptionRootState: Equatable {
    case loading
    case subscriptionWelcome
    case subscriptionUnavailable
    case ownerSetup
    case app(readOnly: Bool)
}

nonisolated enum SubscriptionRootRules {
    static func state(
        access: SubscriptionAccess,
        hasIdentity: Bool
    ) -> SubscriptionRootState {
        switch access {
        case .loading:
            .loading
        case .free:
            hasIdentity ? .app(readOnly: true) : .subscriptionWelcome
        case .unavailable:
            hasIdentity ? .app(readOnly: true) : .subscriptionUnavailable
        case .pro:
            hasIdentity ? .app(readOnly: false) : .ownerSetup
        }
    }
}
