import XCTest

final class BusinessNavigationUITests: XCTestCase {
    @MainActor
    func testBusinessDestinationsAndSharedRecordLinks() {
        let app = launch()
        defer { app.terminate() }
        verifyDestinations(in: app)

        app.openBusinessRoot()
        app.buttons["Service Locations"].tap()
        let location = app.buttons["barn-row-Willow Creek Stables"]
        XCTAssertTrue(location.waitForExistence(timeout: 3))
        location.tap()
        let horse = app.buttons["horse-row-Atlas"]
        reveal(horse, in: app)
        horse.tap()
        XCTAssertTrue(app.navigationBars["Atlas"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["horse-detail-client"].exists)
        app.openBusinessRoot()
        XCTAssertTrue(app.navigationBars["Business"].exists)
    }

    @MainActor
    func testBusinessAtLargestTextInDarkModeAndReadOnly() {
        let app = launch(largestText: true, readOnly: true)
        defer { app.terminate() }
        verifyDestinations(in: app)
        app.openBusinessRoot()
        app.selectFarrierFlowTab("Clients")
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Add Client"].exists)
        XCTAssertFalse(app.buttons["More"].exists)
    }

    @MainActor
    func testBusinessProfileSavePersistsAndOtherTabsRemainAvailable() {
        let app = launch()
        defer { app.terminate() }
        app.openBusinessRoot()
        app.buttons["Business Profile"].tap()
        let name = app.textFields["business-profile-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText(" Updated")
        guard let updatedName = name.value as? String else {
            XCTFail("The business name should expose its edited value")
            return
        }
        XCTAssertTrue(updatedName.contains("Updated"))
        app.buttons["business-profile-save-action"].tap()
        XCTAssertTrue(app.navigationBars["Business"].waitForExistence(timeout: 3))
        app.selectFarrierFlowTab("Today")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.openBusinessRoot()
        app.buttons["Business Profile"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, updatedName.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @MainActor
    private func verifyDestinations(in app: XCUIApplication) {
        app.openBusinessRoot()
        capture(app, "Business grouped native list")
        for (row, title) in [
            ("Service Locations", "Service Locations"),
            ("Services", "Services"),
            ("Invoices", "Invoices"),
            ("Business Profile", "My Business"),
            ("Subscription", "Subscription"),
            ("backup-sync-open", "Backup & Sync"),
        ] {
            app.openBusinessRoot()
            let link = app.buttons[row]
            reveal(link, in: app)
            XCTAssertFalse(link.label.isEmpty)
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), app.debugDescription)
            if app.tabBars.firstMatch.exists {
                XCTAssertTrue(app.tabBars.buttons["Business"].isSelected)
            }
        }
    }

    @MainActor
    private func launch(largestText: Bool = false, readOnly: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "BusinessNavigation-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = readOnly ? "read-only" : "full"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
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
