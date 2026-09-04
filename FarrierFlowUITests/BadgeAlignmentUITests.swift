import XCTest

final class BadgeAlignmentUITests: XCTestCase {
    @MainActor
    func testAppointmentStatusUsesNativeRowBadgeValue() {
        let app = launch(accessibilitySize: false)
        defer { app.terminate() }
        openTab("Schedule", in: app)
        let row = app.buttons["appointment-row-Invoice Service Location"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, "Completed")
        row.tap()
        XCTAssertTrue(app.buttons["visit-view-action"].waitForExistence(timeout: 5))
        app.buttons["visit-view-action"].tap()
        let result = app.descendants(matching: .any)["visit-result-Milo"].firstMatch
        for _ in 0..<5 where !result.isHittable { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue((result.value as? String)?.contains("Serviced") == true)
        capture(app, named: "Native visit result badge")
        let photographs = app.buttons["visit-result-photographs-Milo"]
        for _ in 0..<5 where !photographs.isHittable || photographs.frame.maxY > app.frame.maxY - 80 {
            app.swipeUp()
        }
        XCTAssertTrue(photographs.waitForExistence(timeout: 5))
        photographs.tap()
        XCTAssertTrue(app.navigationBars["Hoof Photos"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRecordRowTrailingEdgeStillNavigates() {
        let app = launch(accessibilitySize: false)
        defer { app.terminate() }
        openTab("Schedule", in: app)
        let row = app.buttons["appointment-row-Invoice Service Location"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["visit-view-action"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRecordBadgesRemainReadableInLightMode() {
        checkRecordBadges(colorScheme: "light", accessibilitySize: false)
    }

    @MainActor
    func testRecordBadgesRemainReadableInDarkMode() {
        checkRecordBadges(colorScheme: "dark", accessibilitySize: false)
    }

    @MainActor
    func testNativeRecordBadgesRemainReadableAtAccessibilityTextSize() {
        checkRecordBadges(colorScheme: "light", accessibilitySize: true)
    }

    @MainActor
    func testInvoiceListStatusRemainsReadableAtAccessibilityTextSize() {
        let app = launch(accessibilitySize: true)
        defer { app.terminate() }
        openTab("Clients", in: app)
        app.buttons["More"].tap()
        app.buttons["Invoices"].tap()
        let invoice = app.buttons["invoice-row-0001"]
        XCTAssertTrue(invoice.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: invoice).contains("Unpaid"))
        XCTAssertLessThan(invoice.frame.height, app.frame.height)
        capture(app, named: "Invoice list accessibility status")
        invoice.tap()
        XCTAssertTrue(app.staticTexts["invoice-detail-total"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStackedInvoiceAmountUsesTheSameLeadingEdgeAsItsLabel() {
        let app = launch(accessibilitySize: true)
        defer { app.terminate() }

        let review = app.buttons["today-review-invoice-action"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        let total = app.staticTexts["invoice-detail-total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        let summary = app.descendants(matching: .any)["invoice-detail-amount-due"].firstMatch
        let label = summary.staticTexts["Amount Due"]
        XCTAssertTrue(label.waitForExistence(timeout: 3))
        capture(app, named: "Invoice header accessibility alignment")

        XCTAssertEqual(total.frame.minX, label.frame.minX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(label.frame.minY, total.frame.maxY)
        XCTAssertLessThanOrEqual(total.frame.maxX, app.frame.maxX - 16)
    }

    @MainActor
    private func checkRecordBadges(colorScheme: String, accessibilitySize: Bool) {
        let app = launch(accessibilitySize: accessibilitySize, colorScheme: colorScheme)
        defer { app.terminate() }

        openTab("Schedule", in: app)
        let appointment = app.buttons["appointment-row-Invoice Service Location"].firstMatch
        XCTAssertTrue(appointment.waitForExistence(timeout: 5))
        if accessibilitySize {
            XCTAssertTrue(accessibilityText(of: appointment).contains("Completed"))
        } else {
            XCTAssertEqual(appointment.value as? String, "Completed")
        }
        XCTAssertTrue(appointment.label.contains("Milo"))
        XCTAssertGreaterThanOrEqual(appointment.frame.minX, 16)
        XCTAssertLessThanOrEqual(appointment.frame.maxX, app.frame.maxX - 16)
        XCTAssertLessThan(appointment.frame.height, app.frame.height,
                          "A status must not squeeze the record into a screen-tall text column.")
        capture(app, named: "Schedule \(colorScheme) accessibility \(accessibilitySize)")

        openTab("Clients", in: app)
        let client = app.buttons["client-row-Invoice Client"]
        XCTAssertTrue(client.waitForExistence(timeout: 5))
        client.tap()
        let invoice = app.buttons["client-invoice-0001"]
        for _ in 0..<5 where !invoice.isHittable { app.swipeUp() }
        XCTAssertTrue(invoice.waitForExistence(timeout: 5))
        XCTAssertTrue(invoice.isHittable)
        if accessibilitySize {
            XCTAssertTrue(accessibilityText(of: invoice).contains("Unpaid"))
        } else {
            XCTAssertEqual(invoice.value as? String, "Unpaid")
        }
        capture(app, named: "Client invoice \(colorScheme) accessibility \(accessibilitySize)")
        invoice.tap()
        XCTAssertTrue(app.staticTexts["invoice-detail-total"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        for _ in 0..<2 {
            tab.tap()
            if app.navigationBars[title].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Expected the \(title) tab to open")
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String].compactMap { $0 }.joined(separator: ", ")
    }

    @MainActor
    private func launch(accessibilitySize: Bool, colorScheme: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "BadgeAlignment-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = colorScheme
        if accessibilitySize {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
