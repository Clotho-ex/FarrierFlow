import XCTest

final class ServiceDeletionUITests: XCTestCase {
    @MainActor
    func testContentSizedSheetCancelsAndDeletesOnlyAfterConfirmation() {
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
        app.buttons["Actions"].tap()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.textFields["service-name-field"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["service-name-field"].value as? String, "Delete Me")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Delete Me"].waitForExistence(timeout: 3))
        app.buttons["Actions"].tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Status", "Archived")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Actions"].tap()
        app.buttons["Reactivate"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Status", "Active")).firstMatch.waitForExistence(timeout: 3))
        openConfirmation(in: app)
        let sheet = app.scrollViews["service-delete-sheet"]
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.isHittable)
        XCTAssertLessThan(sheet.frame.height, app.frame.height * 0.48)
        XCTAssertLessThan(sheet.frame.maxY - cancel.frame.maxY, 65)
        capture(app, "Service deletion fits standard text light")
        cancel.tap()
        XCTAssertTrue(app.navigationBars["Delete Me"].waitForExistence(timeout: 3))

        openConfirmation(in: app)
        app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.navigationBars["Delete Me"].waitForExistence(timeout: 3))
        XCTAssertFalse(sheet.exists)
        openConfirmation(in: app)
        app.buttons["service-delete-confirmation"].tap()
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
    func testLargestTextSheetDeletesServiceAndRecordedWork() {
        let app = launch("ServiceDeleteBlocked-\(UUID().uuidString)", largestText: true)
        defer { app.terminate() }
        openServices(in: app)
        let row = app.buttons["service-row-Trim"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        openConfirmation(in: app)
        let sheet = app.scrollViews["service-delete-sheet"]
        XCTAssertGreaterThan(sheet.frame.height, app.frame.height * 0.5)
        let cancel = app.buttons["Cancel"]
        for _ in 0..<6 {
            if cancel.isHittable && cancel.frame.maxY < app.frame.maxY - 30 { break }
            sheet.swipeUp()
        }
        XCTAssertTrue(cancel.isHittable)
        capture(app, "Service deletion accommodates largest text dark")
        let confirm = app.buttons["service-delete-confirmation"]
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        openServices(in: app)
        XCTAssertFalse(app.buttons["service-row-Trim"].exists)

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
        app.buttons["Services"].tap()
        XCTAssertTrue(app.navigationBars["Services"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openConfirmation(in app: XCUIApplication) {
        app.buttons["Actions"].tap()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["service-delete-confirmation"].waitForExistence(timeout: 3))
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
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        return app
    }
}
