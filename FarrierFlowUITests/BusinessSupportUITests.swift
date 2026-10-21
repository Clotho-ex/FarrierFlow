import XCTest

final class BusinessSupportUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testLocalContentAndSupportWhileSubscriptionVerificationIsPending() {
        let app = launch(access: "verification-pending")
        defer { app.terminate() }
        XCTAssertFalse(app.staticTexts["Loading FarrierFlow…"].exists)
        app.selectFarrierFlowTab("Clients")
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Add Client"].exists)
        verifySupport(in: app)
        app.selectFarrierFlowTab("Today")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSupportAtLargestTextInDarkMode() {
        let app = launch(access: "read-only", largestText: true)
        defer { app.terminate() }
        verifySupport(in: app)
    }

    @MainActor
    private func verifySupport(in app: XCUIApplication) {
        app.openBusinessRoot()
        let help = app.buttons["Help & Support"]
        reveal(help, in: app)
        capture(app, "Business Support section")
        help.tap()
        XCTAssertTrue(app.navigationBars["Help & Support"].waitForExistence(timeout: 3))
        for label in ["Help Center", "Contact Support", "Privacy Policy", "Terms of Use"] {
            let link = app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "(elementType == %d OR elementType == %d) AND label CONTAINS %@",
                    XCUIElement.ElementType.button.rawValue,
                    XCUIElement.ElementType.link.rawValue,
                    label
                )
            ).firstMatch
            reveal(link, in: app)
        }
        capture(app, "Help and legal links")

        app.openBusinessRoot()
        let about = app.buttons["About FarrierFlow"]
        reveal(about, in: app)
        about.tap()
        XCTAssertTrue(app.navigationBars["About FarrierFlow"].waitForExistence(timeout: 3))
        let version = app.staticTexts["about-app-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 3))
        XCTAssertTrue(version.label.hasPrefix("Version "))
        XCTAssertFalse(version.label.contains("unavailable"))
        let installedVersion = version.label
        capture(app, "About installed version")
        app.openBusinessRoot()
        let footer = app.descendants(matching: .any)["business-app-version"].firstMatch
        reveal(footer, in: app)
        XCTAssertTrue(footer.label.contains(installedVersion), footer.label)
        capture(app, "Business version footer")
    }

    @MainActor
    private func launch(access: String, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "BusinessSupport-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = access
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5), app.debugDescription)
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
