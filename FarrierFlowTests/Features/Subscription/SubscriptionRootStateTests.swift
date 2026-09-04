import Testing
@testable import FarrierFlow

@Suite("Subscription root state")
struct SubscriptionRootStateTests {
    @Test
    func unavailableAccessWithoutIdentityDoesNotPresentAFreeSubscriptionConclusion() {
        #expect(
            SubscriptionRootRules.state(
                access: .unavailable,
                hasIdentity: false,
                hasExistingBusinessData: false
            )
                != .subscriptionWelcome
        )
    }

    @Test(arguments: [
        (SubscriptionAccess.loading, false, false, SubscriptionRootState.loading),
        (.free, false, false, .subscriptionWelcome),
        (.pro, false, false, .ownerSetup),
        (.unavailable, false, false, .subscriptionUnavailable),
        (.free, true, false, .app(readOnly: true)),
        (.unavailable, true, false, .app(readOnly: true)),
        (.pro, true, false, .app(readOnly: false)),
        (.free, false, true, .app(readOnly: true)),
        (.unavailable, false, true, .app(readOnly: true)),
        (.pro, false, true, .ownerSetup),
    ])
    func rootState(
        access: SubscriptionAccess,
        hasIdentity: Bool,
        hasExistingBusinessData: Bool,
        expected: SubscriptionRootState
    ) {
        #expect(
            SubscriptionRootRules.state(
                access: access,
                hasIdentity: hasIdentity,
                hasExistingBusinessData: hasExistingBusinessData
            )
                == expected
        )
    }
}
