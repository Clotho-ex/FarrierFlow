import XCTest

final class SubscriptionFlowUITests: XCTestCase {
    @MainActor
    func testReadOnlyWithoutIdentityStartsReleaseOnboarding() {
        let app = launch(
            storeName: "SubscriptionWelcome-\(UUID().uuidString)",
            scenario: "owner-setup"
        )
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding-welcome"]
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

        let monthly = app.buttons["subscription-plan-monthly"]
        let annual = app.buttons["subscription-plan-annual"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        XCTAssertTrue(annual.exists)
        XCTAssertTrue(accessibilityText(of: monthly).contains("$14.99"))
        XCTAssertTrue(accessibilityText(of: monthly).contains("2 weeks free"))
        XCTAssertTrue(accessibilityText(of: annual).contains("$119.99"))
        XCTAssertTrue(accessibilityText(of: annual).contains("$10.00 per month"))
        XCTAssertTrue(accessibilityText(of: annual).contains("2 weeks free"))
        XCTAssertTrue(accessibilityText(of: annual).contains("Save 33%"))
        XCTAssertEqual(monthly.frame.midY, annual.frame.midY, accuracy: 2)
        XCTAssertLessThan(monthly.frame.minX, annual.frame.minX)
        XCTAssertFalse(monthly.isSelected)
        XCTAssertTrue(annual.isSelected)
        XCTAssertTrue(app.staticTexts["Yearly Pro"].exists)
        XCTAssertTrue(
            app.staticTexts["Save 33% compared with monthly"].exists
        )
        XCTAssertFalse(app.buttons["subscription-continue-read-only"].exists)
        let purchase = app.buttons["subscription-primary-purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 3))
        XCTAssertEqual(purchase.label, "Start 2-Week Free Trial")
        XCTAssertTrue(
            app.staticTexts["2 weeks free, then $119.99/year. Cancel anytime."]
                .exists
        )
        XCTAssertTrue(app.staticTexts["$10.00/month, billed annually."].exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Just")
        ).firstMatch.exists)
        monthly.tap()
        XCTAssertTrue(monthly.isSelected)
        XCTAssertFalse(annual.isSelected)
        XCTAssertTrue(app.staticTexts["Monthly Pro"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Flexible monthly billing"].exists)
        annual.tap()
        XCTAssertTrue(annual.isSelected)
        XCTAssertTrue(app.staticTexts["Yearly Pro"].waitForExistence(timeout: 2))
        purchase.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFreshEmptyWorkspaceCannotBypassTheOnboardingPaywall() {
        let app = launchWelcome(access: "read-only")
        defer { app.terminate() }

        XCTAssertFalse(app.buttons["subscription-continue-read-only"].exists)
        XCTAssertFalse(app.navigationBars["Today"].exists)
        XCTAssertTrue(app.buttons["subscription-primary-purchase"].isHittable)
        XCTAssertTrue(app.buttons["subscription-restore"].isHittable)
    }

    @MainActor
    func testPurchaseCancellationReturnsToPaywallWithoutError() {
        let app = launchWelcome(access: "purchase-cancellation")
        defer { app.terminate() }

        let annual = app.buttons["subscription-plan-annual"]
        XCTAssertTrue(annual.waitForExistence(timeout: 5))
        annual.tap()
        app.buttons["subscription-primary-purchase"].tap()
        XCTAssertTrue(annual.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["subscription-error"].exists)
        XCTAssertFalse(app.navigationBars["Today"].exists)
        XCTAssertTrue(app.buttons["subscription-primary-purchase"].isEnabled)
    }

    @MainActor
    func testPlanWithoutIntroductoryOfferUsesSubscribeAction() {
        let app = launchWelcome(access: "no-trial")
        defer { app.terminate() }

        let monthly = app.buttons["subscription-plan-monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        monthly.tap()
        let purchase = app.buttons["subscription-primary-purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 5))
        XCTAssertEqual(purchase.label, "Subscribe")
        XCTAssertFalse(accessibilityText(of: monthly)
            .contains("free"))
        XCTAssertTrue(
            app.staticTexts[
                "$14.99/month. Renews automatically. Cancel anytime."
            ].exists
        )
    }

    @MainActor
    func testPurchaseFailureShowsRecoverableError() {
        let app = launchWelcome(access: "purchase-failure")
        defer { app.terminate() }

        let monthly = app.buttons["subscription-plan-monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        monthly.tap()
        app.buttons["subscription-primary-purchase"].tap()
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
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOutageFailsClosedAndOffersRetry() {
        let app = launchWelcome(access: "outage")
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["subscription-retry"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["subscription-plan-annual"].exists)
        XCTAssertFalse(app.buttons["subscription-continue-read-only"].exists)
        XCTAssertTrue(app.buttons["subscription-restore"].exists)
        XCTAssertFalse(app.navigationBars["Today"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.navigationBars["FarrierFlow Pro"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.descendants(matching: .any)["onboarding-welcome"].exists)
    }

    @MainActor
    func testOutageWithExistingProfileDoesNotClaimSubscriptionIsRequired() {
        let app = launch(
            storeName: "SubscriptionOutage-\(UUID().uuidString)",
            access: "outage"
        )
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Subscription Status Unavailable"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.staticTexts["Subscription Required"].exists)
    }

    @MainActor
    private func launch(
        storeName: String,
        scenario: String? = nil,
        access: String = "read-only"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = access
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
        let getStarted = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(getStarted))
        let name = app.textFields["business-profile-name-field"]
        for _ in 0..<2 where !name.exists {
            getStarted.tap()
            _ = name.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(name.exists)
        for _ in 0..<2 where !app.keyboards.firstMatch.exists {
            name.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        name.typeText("Carter Field Farrier")
        let save = app.buttons["business-profile-save-action"]
        let subscription = app.navigationBars["FarrierFlow Pro"]
        for _ in 0..<2 where !subscription.exists {
            XCTAssertTrue(save.isHittable)
            save.tap()
            _ = subscription.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(subscription.exists)
        return app
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [enabled], timeout: 3) == .completed
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

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
