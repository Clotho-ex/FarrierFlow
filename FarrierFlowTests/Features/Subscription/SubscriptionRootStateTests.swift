import Testing
@testable import FarrierFlow

@Suite("Subscription root state")
struct SubscriptionRootStateTests {
    @Test(arguments: [
        (SubscriptionAccess.loading, false, SubscriptionRootState.loading),
        (.readOnly, false, .subscriptionWelcome),
        (.full, false, .ownerSetup),
        (.readOnly, true, .app(readOnly: true)),
        (.full, true, .app(readOnly: false)),
    ])
    func rootState(
        access: SubscriptionAccess,
        hasIdentity: Bool,
        expected: SubscriptionRootState
    ) {
        #expect(
            SubscriptionRootRules.state(access: access, hasIdentity: hasIdentity)
                == expected
        )
    }
}
