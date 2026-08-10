import XCTest

final class SubscriptionFlowUITests: XCTestCase {
    @MainActor
    func testReadOnlyWithoutIdentityShowsSubscriptionWelcomeBeforeOwnerSetup() {
        let app = launch(
            storeName: "SubscriptionWelcome-\(UUID().uuidString)",
            scenario: "owner-setup"
        )
        defer { app.terminate() }

        XCTAssertTrue(
            app.otherElements["subscription-welcome"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.textFields["business-profile-name-field"].exists)
    }

    @MainActor
    func testReadOnlyProfileShowsTodayNoticeAndSubscriptionFromClientsMore() {
        let app = launch(storeName: "SubscriptionReadOnly-\(UUID().uuidString)")
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let notice = app.buttons["subscription-read-only-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "subscription-read-only-notice").count, 1)

        openClients(in: app)
        let subscription = openMore(in: app)
        subscription.tap()

        XCTAssertTrue(app.navigationBars["Subscription"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func launch(storeName: String, scenario: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        if let scenario {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = scenario
        }
        app.launch()
        return app
    }

    @MainActor
    private func openClients(in app: XCUIApplication) {
        let clients = app.tabBars.buttons["Clients"]
        for _ in 0..<2 {
            clients.tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 2) {
                return
            }
        }
        XCTFail("Clients did not open")
    }

    @MainActor
    private func openMore(in app: XCUIApplication) -> XCUIElement {
        let more = app.buttons["More"].firstMatch
        let subscription = app.buttons["Subscription"]
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        XCTAssertTrue(more.isHittable)
        guard more.isHittable else { return subscription }

        more.tap()
        XCTAssertTrue(subscription.waitForExistence(timeout: 3))
        return subscription
    }
}
