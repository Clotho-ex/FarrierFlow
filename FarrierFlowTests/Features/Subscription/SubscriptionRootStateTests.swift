import Testing
@testable import FarrierFlow

@Suite("Subscription root state")
struct SubscriptionRootStateTests {
    @Test
    func unavailableAccessWithoutIdentityDoesNotPresentAFreeSubscriptionConclusion() {
        #expect(
            SubscriptionRootRules.state(access: .unavailable, hasIdentity: false)
                != .subscriptionWelcome
        )
    }

    @Test(arguments: [
        (SubscriptionAccess.loading, false, SubscriptionRootState.loading),
        (.free, false, .subscriptionWelcome),
        (.pro, false, .ownerSetup),
        (.unavailable, false, .subscriptionUnavailable),
        (.free, true, .app(readOnly: true)),
        (.unavailable, true, .app(readOnly: true)),
        (.pro, true, .app(readOnly: false)),
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
