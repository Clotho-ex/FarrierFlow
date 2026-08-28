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
            app.descendants(matching: .any)["subscription-welcome"]
                .waitForExistence(timeout: 5)
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
    func testPaywallShowsLocalizedAnnualAndMonthlyPlansAndPurchasesPro() {
        let app = launchWelcome(access: "read-only")
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["subscription-plan-annual"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["$119.99"].exists)
        XCTAssertTrue(app.buttons["subscription-plan-monthly"].exists)
        app.buttons["subscription-plan-annual"].tap()
        XCTAssertTrue(app.textFields["business-profile-name-field"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPurchaseCancellationReturnsToPaywallWithoutError() {
        let app = launchWelcome(access: "purchase-cancellation")
        defer { app.terminate() }

        let annual = app.buttons["subscription-plan-annual"]
        XCTAssertTrue(annual.waitForExistence(timeout: 5))
        annual.tap()
        XCTAssertTrue(annual.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["subscription-error"].exists)
    }

    @MainActor
    func testPurchaseFailureShowsRecoverableError() {
        let app = launchWelcome(access: "purchase-failure")
        defer { app.terminate() }

        let monthly = app.buttons["subscription-plan-monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        monthly.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["subscription-error"]
                .waitForExistence(timeout: 3)
        )
    }

    @MainActor
    func testRestoreSuccessGrantsPro() {
        let app = launchWelcome(access: "restore-success")
        defer { app.terminate() }

        let restore = app.buttons["subscription-restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(
            app.textFields["business-profile-name-field"]
                .waitForExistence(timeout: 3)
        )
    }

    @MainActor
    func testOutageFailsClosedAndOffersRetry() {
        let app = launchWelcome(access: "outage")
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["subscription-retry"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["subscription-plan-annual"].exists)
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
    private func launchWelcome(access: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "Subscription-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = access
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
        let waiterResult = XCTWaiter().wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "isHittable == true"),
                    object: more
                )
            ],
            timeout: 3
        )
        XCTAssertEqual(waiterResult, .completed)
        guard waiterResult == .completed else { return subscription }

        more.tap()
        XCTAssertTrue(subscription.waitForExistence(timeout: 3))
        return subscription
    }
}
