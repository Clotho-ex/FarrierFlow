nonisolated enum SubscriptionRootState: Equatable {
    case loading
    case subscriptionWelcome
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
        case .readOnly:
            hasIdentity ? .app(readOnly: true) : .subscriptionWelcome
        case .full:
            hasIdentity ? .app(readOnly: false) : .ownerSetup
        }
    }
}
