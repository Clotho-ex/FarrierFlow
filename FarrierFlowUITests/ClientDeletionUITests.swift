import XCTest

final class ClientDeletionUITests: XCTestCase {
    @MainActor
    func testNativeAlertCancelsAndDeletesOnlyAfterConfirmation() {
        let store = "ClientDelete-\(UUID().uuidString)"
        var app = launch(store)
        openClients(in: app)
        app.buttons["Add Client"].tap()
        let name = app.textFields["client-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Delete Me")
        app.buttons["Save"].tap()
        let row = app.buttons["client-row-Delete Me"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()

        openConfirmation(in: app)
        let alert = app.alerts["Delete Client?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertFalse(app.scrollViews["client-delete-sheet"].exists)
        capture(app, "Native client deletion alert standard text")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Delete Me"].exists)

        openConfirmation(in: app)
        app.buttons["client-delete-confirmation"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 3))
        XCTAssertFalse(row.exists)
        app.terminate()
        app = launch(store)
        defer { app.terminate() }
        openClients(in: app)
        XCTAssertTrue(app.buttons["client-row-Today Client"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["client-row-Delete Me"].exists)
    }

    @MainActor
    func testNativeAlertAtLargestTextDeletesClientAndItsHorses() {
        let app = launch("ClientDeleteBlocked-\(UUID().uuidString)", largestText: true)
        defer { app.terminate() }
        openClients(in: app)
        let row = app.buttons["client-row-Today Client"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        openConfirmation(in: app)
        let alert = app.alerts["Delete Client?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.buttons["Cancel"].isHittable)
        capture(app, "Native client deletion alert largest text dark")
        let confirm = app.buttons["client-delete-confirmation"].firstMatch
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openClients(in: app)
        XCTAssertFalse(app.buttons["client-row-Today Client"].exists)

    }

    @MainActor
    private func openClients(in app: XCUIApplication) {
        for _ in 0..<2 {
            if app.navigationBars["Clients"].exists { break }
            let tab = app.tabBars.buttons["Clients"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 5) { break }
        }
        XCTAssertTrue(app.navigationBars["Clients"].exists)
    }

    @MainActor
    private func openConfirmation(in app: XCUIApplication) {
        let client = app.navigationBars["Client"]
        XCTAssertTrue(client.waitForExistence(timeout: 5))
        let actions = client.buttons["Actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.buttons["client-delete-confirmation"].firstMatch.waitForExistence(timeout: 5))
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
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = store
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "today-stops"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        return app
    }
}
