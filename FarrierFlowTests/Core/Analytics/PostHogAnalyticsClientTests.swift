import Foundation
import PostHog
import Testing
@testable import FarrierFlow

@Suite("PostHog analytics provider")
@MainActor
struct PostHogAnalyticsClientTests {
    @Test
    func missingConfigurationFallsBackToNoOpWithoutConstructingProvider() {
        var constructedProvider = false

        let client = AnalyticsClientComposition.make(
            infoDictionary: [:],
            providerFactory: { _ in
                constructedProvider = true
                return AnalyticsSpy()
            }
        )

        #expect(client is NoOpAnalyticsClient)
        #expect(!constructedProvider)
    }

    @Test
    func malformedConfigurationFallsBackToNoOp() {
        let client = AnalyticsClientComposition.make(
            infoDictionary: [
                PostHogAnalyticsConfiguration.projectTokenInfoKey: "not-a-project-token",
                PostHogAnalyticsConfiguration.hostInfoKey: "http://us.i.posthog.com",
            ]
        )

        #expect(client is NoOpAnalyticsClient)

        let pathClient = AnalyticsClientComposition.make(
            infoDictionary: [
                PostHogAnalyticsConfiguration.projectTokenInfoKey: "phc_test_public_project_token",
                PostHogAnalyticsConfiguration.hostInfoKey: "https://us.i.posthog.com/not-an-origin",
            ]
        )
        #expect(pathClient is NoOpAnalyticsClient)
    }

    @Test
    func validConfigurationSelectsProviderAndPreservesCentralValues() throws {
        let expectedToken = "phc_test_public_project_token"
        let expectedHost = "https://us.i.posthog.com"
        var receivedConfiguration: PostHogAnalyticsConfiguration?
        let provider = AnalyticsSpy()

        let client = AnalyticsClientComposition.make(
            infoDictionary: [
                PostHogAnalyticsConfiguration.projectTokenInfoKey: expectedToken,
                PostHogAnalyticsConfiguration.hostInfoKey: expectedHost,
            ],
            providerFactory: { configuration in
                receivedConfiguration = configuration
                return provider
            }
        )

        #expect(client as AnyObject === provider)
        #expect(receivedConfiguration?.projectToken == expectedToken)
        #expect(receivedConfiguration?.host == URL(string: expectedHost))
    }

    @Test
    func providerCapturesStableNamesAndOnlyApprovedTypedProperties() {
        var captures: [(String, [String: Any]?)] = []
        let client = PostHogAnalyticsClient { name, properties in
            captures.append((name, properties))
        }

        client.track(.visitCompleted)
        client.track(.subscriptionPurchaseStarted(.annual))

        #expect(captures.count == 2)
        #expect(captures[0].0 == "visit_completed")
        #expect(captures[0].1?["$geoip_disable"] as? Bool == true)
        #expect(captures[0].1?.count == 1)
        #expect(captures[1].0 == "subscription_purchase_started")
        #expect(captures[1].1?["plan"] as? String == "annual")
        #expect(captures[1].1?["$geoip_disable"] as? Bool == true)
        #expect(captures[1].1?.count == 2)
    }

    @Test
    func sdkConfigurationDisablesUnapprovedAutomaticFeatures() throws {
        let configuration = try PostHogAnalyticsConfiguration(
            infoDictionary: [
                PostHogAnalyticsConfiguration.projectTokenInfoKey: "phc_test_public_project_token",
                PostHogAnalyticsConfiguration.hostInfoKey: "https://us.i.posthog.com",
            ]
        )

        let sdkConfiguration = PostHogAnalyticsClient.sdkConfiguration(for: configuration)

        #expect(!sdkConfiguration.captureApplicationLifecycleEvents)
        #expect(!sdkConfiguration.captureScreenViews)
        #expect(!sdkConfiguration.enableSwizzling)
        #expect(!sdkConfiguration.captureElementInteractions)
        #expect(!sdkConfiguration.capturePushNotificationSubscriptions)
        #expect(!sdkConfiguration.capturePushNotificationOpened)
        #expect(!sdkConfiguration.preloadFeatureFlags)
        #expect(!sdkConfiguration.sendFeatureFlagEvent)
        #expect(!sdkConfiguration.setDefaultPersonProperties)
        #expect(sdkConfiguration.personProfiles == .never)
        #expect(!sdkConfiguration.sessionReplay)
        #expect(!sdkConfiguration.surveys)
        #expect(!sdkConfiguration.errorTrackingConfig.autoCapture)
        #expect(!sdkConfiguration.debug)
        #expect(!sdkConfiguration.rageClickConfig.enabled)
        #expect(sdkConfiguration.tracingHeaders == nil)
    }
}
