import Foundation
import Testing
@testable import FarrierFlow

#if DEBUG
@Suite("UI test launch configuration")
@MainActor
struct UITestLaunchConfigurationTests {
    private let supportURL = URL(filePath: "/tmp/FarrierFlow-Launch-Configuration-Tests")

    @Test
    func screenshotModeRequiresAndResolvesDeterministicIsolatedInputs() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-09-06T13:41:00Z")
        )
        let configuration = UITestLaunchConfiguration(
            environment: [
                "FARRIERFLOW_SCREENSHOT_MODE": "1",
                "FARRIERFLOW_UI_TEST_STORE": "Screenshots-Active",
                "FARRIERFLOW_UI_TEST_SCENARIO": "app-store-showcase",
                "FARRIERFLOW_UI_TEST_NOW": "2026-09-06T13:41:00Z",
                "FARRIERFLOW_SCREENSHOT_STAGE": "active",
            ],
            applicationSupportURL: supportURL
        )

        #expect(configuration.launchMode == .isolated)
        #expect(configuration.isScreenshotMode)
        #expect(configuration.scenario == .appStoreShowcase)
        #expect(configuration.screenshotStage == .active)
        #expect(
            configuration.storeURL
                == supportURL
                    .appending(path: "UITests", directoryHint: .isDirectory)
                    .appending(path: "Screenshots-Active.store")
        )
        #expect(configuration.referenceDate == referenceDate)
        #expect(configuration.subscriptionAccess == .full)
    }

    @Test(arguments: [
        [
            "FARRIERFLOW_SCREENSHOT_MODE": "1",
            "FARRIERFLOW_UI_TEST_SCENARIO": "app-store-showcase",
            "FARRIERFLOW_UI_TEST_NOW": "2026-09-06T13:41:00Z",
            "FARRIERFLOW_SCREENSHOT_STAGE": "active",
        ],
        [
            "FARRIERFLOW_SCREENSHOT_MODE": "1",
            "FARRIERFLOW_UI_TEST_STORE": "Screenshots-Active",
            "FARRIERFLOW_UI_TEST_NOW": "2026-09-06T13:41:00Z",
            "FARRIERFLOW_SCREENSHOT_STAGE": "active",
        ],
        [
            "FARRIERFLOW_SCREENSHOT_MODE": "1",
            "FARRIERFLOW_UI_TEST_STORE": "Screenshots-Active",
            "FARRIERFLOW_UI_TEST_SCENARIO": "app-store-showcase",
            "FARRIERFLOW_SCREENSHOT_STAGE": "active",
        ],
        [
            "FARRIERFLOW_SCREENSHOT_MODE": "1",
            "FARRIERFLOW_UI_TEST_STORE": "Screenshots-Active",
            "FARRIERFLOW_UI_TEST_SCENARIO": "app-store-showcase",
            "FARRIERFLOW_UI_TEST_NOW": "not-a-date",
            "FARRIERFLOW_SCREENSHOT_STAGE": "active",
        ],
        [
            "FARRIERFLOW_SCREENSHOT_MODE": "1",
            "FARRIERFLOW_UI_TEST_STORE": "Screenshots-Active",
            "FARRIERFLOW_UI_TEST_SCENARIO": "app-store-showcase",
            "FARRIERFLOW_UI_TEST_NOW": "2026-09-06T13:41:00Z",
            "FARRIERFLOW_SCREENSHOT_STAGE": "unknown",
        ],
    ])
    func screenshotModeFailsClosedWhenAnInputIsMissingOrInvalid(
        environment: [String: String]
    ) {
        let configuration = UITestLaunchConfiguration(
            environment: environment,
            applicationSupportURL: supportURL
        )

        #expect(configuration.launchMode == .invalidScreenshot)
    }

    @Test(arguments: ["0", "true", ""])
    func malformedScreenshotModeCannotUseProductionDependencies(value: String) {
        let configuration = UITestLaunchConfiguration(
            environment: ["FARRIERFLOW_SCREENSHOT_MODE": value],
            applicationSupportURL: supportURL
        )

        #expect(configuration.launchMode == .invalidScreenshot)
        #expect(configuration.onboardingDefaults == nil)
    }

    @Test
    func ordinaryLaunchUsesProductionDependencies() {
        let configuration = UITestLaunchConfiguration(
            environment: [:],
            applicationSupportURL: supportURL
        )

        #expect(configuration.launchMode == .production)
        #expect(!configuration.isScreenshotMode)
        #expect(configuration.referenceDate == nil)
        #expect(configuration.screenshotStage == nil)
        #expect(configuration.onboardingDefaults == nil)
    }

    @Test
    func existingUITestStoreStillUsesIsolatedDependencies() {
        let configuration = UITestLaunchConfiguration(
            environment: ["FARRIERFLOW_UI_TEST_STORE": "Existing-UI-Test"],
            applicationSupportURL: supportURL
        )

        #expect(configuration.launchMode == .isolated)
        #expect(!configuration.isScreenshotMode)
    }

    @Test
    func unitTestHostUsesAnIsolatedStore() {
        let configuration = UITestLaunchConfiguration(
            environment: ["FARRIERFLOW_UNIT_TEST_HOST": "1"],
            applicationSupportURL: supportURL
        )

        #expect(configuration.launchMode == .isolated)
        #expect(
            configuration.storeURL
                == supportURL
                    .appending(path: "UITests", directoryHint: .isDirectory)
                    .appending(path: "UnitTestHost.store")
        )
    }

    @Test
    func runningTestHostUsesIsolatedDependencies() {
        #expect(UITestLaunchConfiguration().launchMode == .isolated)
    }

    @Test
    func fixedAppClockAlwaysReturnsTheReferenceInstant() throws {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-09-06T13:41:00Z")
        )
        let clock = AppClock.fixed(referenceDate)

        #expect(clock.now() == referenceDate)
        #expect(clock.now() == referenceDate)
    }
}
#endif
