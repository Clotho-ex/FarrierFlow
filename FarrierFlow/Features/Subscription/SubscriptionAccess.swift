nonisolated enum SubscriptionAccess: Equatable, Sendable {
    case loading
    case full
    case readOnly

    var allowsMutations: Bool {
        self == .full
    }
}
