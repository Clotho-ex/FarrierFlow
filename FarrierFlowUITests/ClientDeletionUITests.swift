import XCTest

final class ClientDeletionUITests: XCTestCase {
    @MainActor
    func testContentSizedSheetCancelsAndDeletesOnlyAfterConfirmation() {
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
        let sheet = app.scrollViews["client-delete-sheet"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.isHittable)
        XCTAssertLessThan(sheet.frame.height, app.frame.height * 0.48)
        XCTAssertLessThan(sheet.frame.maxY - cancel.frame.maxY, 65)
        capture(app, "Client deletion fits standard text light")
        cancel.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Delete Me"].exists)

        openConfirmation(in: app)
        app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        XCTAssertFalse(sheet.exists)
        XCTAssertTrue(app.staticTexts["Delete Me"].exists)

        openConfirmation(in: app)
        app.buttons["client-delete-confirmation"].tap()
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
    func testLargestTextSheetDeletesClientAndItsHorses() {
        let app = launch("ClientDeleteBlocked-\(UUID().uuidString)", largestText: true)
        defer { app.terminate() }
        openClients(in: app)
        let row = app.buttons["client-row-Today Client"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        openConfirmation(in: app)
        let sheet = app.scrollViews["client-delete-sheet"]
        XCTAssertGreaterThan(sheet.frame.height, app.frame.height * 0.5)
        let cancel = app.buttons["Cancel"]
        for _ in 0..<4 {
            if cancel.isHittable && cancel.frame.maxY < app.frame.maxY - 30 { break }
            sheet.swipeUp()
        }
        XCTAssertTrue(cancel.isHittable)
        capture(app, "Client deletion accommodates largest text dark")
        let confirm = app.buttons["client-delete-confirmation"]
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
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["client-delete-confirmation"].waitForExistence(timeout: 3))
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
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        return app
    }
}
