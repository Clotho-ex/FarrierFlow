import Foundation
import Testing
@testable import FarrierFlow

@Suite("RevenueCat attribution configuration")
@MainActor
struct RevenueCatAttributionConfigurationTests {
    @Test
    func validConfigurationEnablesStandardAttributionOnceAfterConfiguration() {
        enum Step: Equatable {
            case configured
            case attributionEnabled
        }

        let expectedPurchases = NSObject()
        var steps: [Step] = []

        let purchases = RevenueCatSubscriptionClient.configurePurchases(
            publicSDKKey: "appl_test_public_sdk_key",
            configure: { key in
                #expect(key == "appl_test_public_sdk_key")
                steps.append(.configured)
                return expectedPurchases
            },
            enableStandardAdServicesAttribution: { configuredPurchases in
                #expect(configuredPurchases === expectedPurchases)
                steps.append(.attributionEnabled)
            }
        )

        #expect(purchases === expectedPurchases)
        #expect(steps == [.configured, .attributionEnabled])
    }

    @Test
    func missingConfigurationDoesNotConstructRevenueCatClient() {
        var clientFactoryCalls = 0

        let client = RevenueCatSubscriptionClientComposition.make(
            publicSDKKey: {
                throw RevenueCatConfigurationError.missingPublicSDKKey
            },
            clientFactory: { _ in
                clientFactoryCalls += 1
                return StaticSubscriptionClient(isPro: true)
            }
        )

        #expect(client is UnavailableSubscriptionClient)
        #expect(clientFactoryCalls == 0)
    }

    @Test
    func validConfigurationConstructsRevenueCatClientOnce() {
        var receivedKeys: [String] = []

        let client = RevenueCatSubscriptionClientComposition.make(
            publicSDKKey: { "appl_test_public_sdk_key" },
            clientFactory: { key in
                receivedKeys.append(key)
                return StaticSubscriptionClient(isPro: true)
            }
        )

        #expect(client is StaticSubscriptionClient)
        #expect(receivedKeys == ["appl_test_public_sdk_key"])
    }

    @Test
    func unavailableClientStillFailsWithoutAUserFacingAttributionState() async {
        let client = RevenueCatSubscriptionClientComposition.make(
            publicSDKKey: {
                throw RevenueCatConfigurationError.missingPublicSDKKey
            }
        )

        await #expect(throws: UnavailableSubscriptionClient.UnavailableError.self) {
            try await client.customerInfo()
        }
        await #expect(throws: UnavailableSubscriptionClient.UnavailableError.self) {
            try await client.restorePurchases()
        }
    }
}
