import XCTest

final class SubscriptionReadOnlyUITests: XCTestCase {
    @MainActor
    func testReadOnlyRecordsRemainNavigableWithoutMutationControls() throws {
        let storeName = "SubscriptionReadOnlyRecords-\(UUID().uuidString)"
        let app = launch(storeName: storeName, access: "full")
        createInvoice(in: app)

        app.terminate()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Schedule Appointment"].exists)

        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(
            app.buttons["appointment-row-Invoice Service Location"].waitForExistence(timeout: 3)
        )
        app.buttons["appointment-row-Invoice Service Location"].firstMatch.tap()
        XCTAssertFalse(app.buttons["visit-start-action"].exists)
        XCTAssertFalse(app.buttons["appointment-delete-action"].exists)
        XCTAssertFalse(app.buttons["Edit"].exists)

        openClients(in: app)
        let client = app.buttons["client-row-Invoice Client"]
        let horse = app.buttons["horse-row-Milo"]
        for _ in 0..<2 where !horse.exists {
            client.tap()
            _ = horse.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(horse.exists)
        guard horse.exists else { return }
        XCTAssertFalse(app.buttons["client-create-invoice-action"].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
        horse.tap()
        let history = app.descendants(matching: .any)["horse-history-visit-Milo"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()
        let hoofPhotos = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Hoof Photos")
        ).firstMatch
        XCTAssertTrue(bringIntoView(hoofPhotos, in: app))
        hoofPhotos.tap()
        let thumbnail = app.buttons["Photo 1 of 1"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 3))
        thumbnail.tap()
        XCTAssertFalse(app.buttons["Delete"].exists)
        app.buttons["Done"].tap()

        openInvoices(in: app)
        app.buttons["invoice-row-0001"].tap()
        let shareInvoice = app.buttons["invoice-share-pdf-action"]
        XCTAssertTrue(shareInvoice.waitForExistence(timeout: 3))
        XCTAssertTrue(shareInvoice.isEnabled)
        XCTAssertFalse(app.buttons["invoice-mark-paid-action"].exists)
        XCTAssertFalse(app.buttons["invoice-delete-action"].exists)
        XCTAssertFalse(app.buttons["invoice-preview-pdf-action"].exists)
        shareInvoice.tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(app.staticTexts["Status, Unpaid"].exists)

        app.terminate()
        app.launch()
        openInvoices(in: app)
        XCTAssertTrue(app.buttons["invoice-row-0001"].waitForExistence(timeout: 3))
        app.buttons["invoice-row-0001"].tap()
        XCTAssertTrue(app.staticTexts["Status, Unpaid"].exists)
        app.navigationBars.buttons["Invoices"].tap()
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertEqual(
            app.buttons.matching(identifier: "appointment-row-Invoice Service Location").count,
            2
        )
    }

    @MainActor
    func testFullAccessKeepsExistingMutationControls() {
        let app = launch(
            storeName: "SubscriptionFullControls-\(UUID().uuidString)",
            access: "full"
        )
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["Schedule Appointment"].waitForExistence(timeout: 5))
        openClients(in: app)
        XCTAssertTrue(app.buttons["Add Client"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func launch(storeName: String, access: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "invoice-ready"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = access
        app.launch()
        return app
    }

    @MainActor
    private func createInvoice(in app: XCUIApplication) {
        openClients(in: app)
        app.buttons["client-row-Invoice Client"].tap()
        app.buttons["client-create-invoice-action"].tap()
        let selectAll = app.buttons["invoice-select-all-action"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 3))
        selectAll.tap()
        app.buttons["invoice-generate-action"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["invoice-detail-0001"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    private func openClients(in app: XCUIApplication) {
        for _ in 0..<2 {
            app.tabBars.buttons["Clients"].tap()
            if app.navigationBars["Clients"].waitForExistence(timeout: 2) {
                return
            }
        }
        XCTFail("Clients tab did not open")
    }

    @MainActor
    private func openInvoices(in app: XCUIApplication) {
        openClients(in: app)
        app.buttons["More"].tap()
        let invoices = app.buttons["Invoices"]
        XCTAssertTrue(invoices.waitForExistence(timeout: 3))
        invoices.tap()
        XCTAssertTrue(app.navigationBars["Invoices"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func bringIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<10 {
            if element.exists, element.isHittable {
                return true
            }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }
}
