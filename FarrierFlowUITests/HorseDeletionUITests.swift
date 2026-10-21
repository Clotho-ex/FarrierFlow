import XCTest

final class HorseDeletionUITests: XCTestCase {
    @MainActor
    func testHorseDeletionSheetCancelsAndDeletesLinkedHistory() {
        verifySheet(largestText: false)
    }

    @MainActor
    func testHorseDeletionSheetSupportsLargestText() {
        verifySheet(largestText: true)
    }

    @MainActor
    private func verifySheet(largestText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "HorseDeletion-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = largestText ? "dark" : "light"
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launch()
        defer { app.terminate() }
        app.tabBars.buttons["Clients"].tap()
        let client = app.buttons["client-row-Invoice Client"]
        XCTAssertTrue(client.waitForExistence(timeout: 5))
        client.tap()
        let horse = app.buttons["horse-row-Milo"]
        reveal(horse, in: app)
        guard horse.exists else { return }
        horse.tap()
        app.buttons["Delete"].tap()
        let confirm = app.buttons["horse-delete-confirmation"]
        guard confirm.waitForExistence(timeout: 3) else {
            XCTFail("Horse deletion must use the shared sheet")
            return
        }
        let cancel = app.buttons["Cancel"]
        reveal(cancel, in: app)
        capture(app, "Horse deletion \(largestText ? "largest Dark" : "standard Light")")
        cancel.tap()
        XCTAssertFalse(confirm.exists)
        XCTAssertTrue(app.buttons["Edit"].exists)

        app.buttons["Delete"].tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        if !largestText {
            let sheet = app.descendants(matching: .any)["horse-delete-sheet"].firstMatch
            XCTAssertLessThan(sheet.frame.height, app.frame.height * 0.75)
            app.buttons["Sheet Grabber"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)
                ))
            XCTAssertFalse(sheet.exists)
            app.buttons["Delete"].tap()
            XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        }
        reveal(confirm, in: app)
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["horse-row-Milo"].exists)
        let invoice = app.buttons["client-invoice-0001"]
        reveal(invoice, in: app)
        XCTAssertTrue(invoice.exists, "Deleting a horse keeps its invoice")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "FARRIERFLOW_UI_TEST_SCENARIO")
        app.launch()
        app.tabBars.buttons["Clients"].tap()
        app.buttons["client-row-Invoice Client"].tap()
        XCTAssertFalse(app.buttons["horse-row-Milo"].exists)

    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
