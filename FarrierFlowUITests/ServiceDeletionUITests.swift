import XCTest

final class ServiceDeletionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testNativeAlertCancelsAndDeletesOnlyAfterConfirmation() {
        let store = "ServiceDelete-\(UUID().uuidString)"
        var app = launch(store)
        openServices(in: app)
        app.buttons["service-add-action"].tap()
        let name = app.textFields["service-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Delete Me")
        let price = app.textFields["service-price-field"]
        price.tap()
        price.typeText("50")
        app.buttons["Save"].tap()
        let row = app.buttons["service-row-Delete Me"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        app.buttons["service-edit-action"].tap()
        XCTAssertTrue(app.textFields["service-name-field"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["service-name-field"].value as? String, "Delete Me")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Delete Me"].waitForExistence(timeout: 3))
        app.buttons["service-archive-action"].tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(app.buttons["service-reactivate-action"].waitForExistence(timeout: 3))
        app.buttons["service-reactivate-action"].tap()
        XCTAssertTrue(app.buttons["service-archive-action"].waitForExistence(timeout: 3))
        openConfirmation(in: app)
        let alert = app.alerts["Delete Service?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        capture(app, "Native service deletion light")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Delete Me"].waitForExistence(timeout: 3))

        openConfirmation(in: app)
        app.buttons["service-delete-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 3))
        XCTAssertFalse(row.exists)
        app.terminate()
        app = launch(store)
        defer { app.terminate() }
        openServices(in: app)
        XCTAssertTrue(app.buttons["service-row-Trim"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["service-row-Delete Me"].exists)
    }

    @MainActor
    func testLargestTextDeletionKeepsRecordedWorkAfterRelaunch() {
        let app = launch("ServiceHistory-\(UUID().uuidString)", largestText: true)
        defer { app.terminate() }
        openServices(in: app)
        let row = app.buttons["service-row-Trim"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        let tabs = app.segmentedControls["service-history-tabs"]
        reveal(tabs, in: app)
        tabs.buttons["Recorded Work"].tap()
        let deletion = app.buttons["service-delete-action"]
        reveal(deletion, in: app)
        XCTAssertTrue(deletion.isEnabled)
        XCTAssertEqual(deletion.images.count, 0)
        capture(app, "Centered text-only service deletion AX dark")
        deletion.tap()
        let alert = app.alerts["Delete Service?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Recorded work, invoices and photos stay.")
        ).firstMatch.exists)
        app.buttons["service-delete-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openServices(in: app)
        XCTAssertFalse(row.exists)
        app.openBusinessRoot()
        let history = app.buttons["business-recorded-work"]
        reveal(history, in: app)
        history.tap()
        XCTAssertTrue(app.navigationBars["Recorded Work"].waitForExistence(timeout: 5))
        let visit = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "business-completed-visit-"
        )).firstMatch
        reveal(visit, in: app)
        visit.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 5))
        let recordedService = app.staticTexts["Trim"].firstMatch
        reveal(recordedService, in: app)
        XCTAssertTrue(recordedService.exists)
        capture(app, "Deleted catalog service keeps recorded work after relaunch")
    }

    @MainActor
    private func openServices(in app: XCUIApplication) {
        for _ in 0..<2 {
            if app.navigationBars["Clients"].exists { break }
            let tab = app.tabBars.buttons["Clients"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 5) { break }
        }
        XCTAssertTrue(app.navigationBars["Clients"].exists)
        app.openBusinessRoot()
        let services = app.buttons["Services"]
        for _ in 0..<8 {
            if services.exists && services.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(services.exists)
        services.tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openConfirmation(in app: XCUIApplication) {
        let deletion = app.buttons["service-delete-action"]
        reveal(deletion, in: app)
        deletion.tap()
        XCTAssertTrue(app.buttons["service-delete-confirmation"].firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launch(_ store: String, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = store
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        return app
    }
}
