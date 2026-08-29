nonisolated enum SubscriptionAccess: Equatable, Sendable {
    case loading
    case free
    case pro
    case unavailable

    var allowsMutations: Bool {
        self == .pro
    }
}

nonisolated enum SubscriptionOperation: Equatable, Sendable {
    case idle
    case purchasing(planID: String)
    case restoring
}

nonisolated enum SubscriptionPlanLoadState: Equatable, Sendable {
    case loading
    case available
    case unavailable
}
