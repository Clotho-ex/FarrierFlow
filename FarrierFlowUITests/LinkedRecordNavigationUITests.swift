import XCTest

final class LinkedRecordNavigationUITests: XCTestCase {
    @MainActor
    func testHorseAndServiceOpenTheirBlockingAppointmentsVisitsAndInvoices() {
        let store = "LinkedRecords-\(UUID().uuidString)"
        var app = launch(store)
        openHorse(in: app)
        let appointment = app.buttons["linked-appointment-Invoice Service Location"].firstMatch
        reveal(appointment, in: app)
        appointment.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Review linked appointments")).firstMatch.exists)
        app.navigationBars.buttons["Milo"].tap()

        let active = app.buttons["linked-visit-Milo"].firstMatch
        reveal(active, in: app)
        active.tap()
        XCTAssertTrue(app.buttons["visit-resume-action"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Milo"].tap()
        app.navigationBars.buttons["Client"].tap()
        app.navigationBars.buttons["Clients"].tap()
        app.openBusinessRoot()
        app.buttons["Services"].tap()
        app.buttons["service-row-Trim"].tap()
        let billedVisit = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "linked-visit-", "Invoice 0001"
        )).firstMatch
        reveal(billedVisit, in: app)
        capture(app, "Service shows linked recorded work and invoice")
        billedVisit.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))
        let invoice = app.buttons["visit-invoice-0001"]
        reveal(invoice, in: app)
        invoice.tap()
        XCTAssertTrue(app.navigationBars["Invoice 0001"].waitForExistence(timeout: 3))
        app.terminate()

        app = launch(store)
        defer { app.terminate() }
        openHorse(in: app)
        XCTAssertTrue(app.buttons["Delete"].exists)
        let linked = app.buttons["linked-appointment-Invoice Service Location"].firstMatch
        reveal(linked, in: app)
        XCTAssertTrue(linked.exists, "Inspection must not delete or rewrite the linked records")
    }

    @MainActor
    private func launch(_ store: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = store
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "deletion-references"
        app.launch()
        return app
    }

    @MainActor
    private func openHorse(in app: XCUIApplication) {
        app.tabBars.buttons["Clients"].tap()
        let client = app.buttons["client-row-Invoice Client"]
        XCTAssertTrue(client.waitForExistence(timeout: 5))
        client.tap()
        let horse = app.buttons["horse-row-Milo"]
        XCTAssertTrue(horse.waitForExistence(timeout: 3))
        horse.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<15 {
            if element.exists, element.isHittable { return }
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
