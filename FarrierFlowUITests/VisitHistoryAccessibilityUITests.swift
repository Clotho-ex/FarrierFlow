import XCTest

final class VisitHistoryAccessibilityUITests: XCTestCase {
    @MainActor
    func testInvoicedVisitOverviewSurfacesServiceLocationAtAccessibilityXXXL() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "VisitHistoryAccessibility-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] =
            "accessibility5"
        app.launch()
        defer { app.terminate() }

        guard openInvoicedVisit(in: app) else { return }

        let overview = app.descendants(matching: .any)[
            "visit-detail-accessibility-overview"
        ].firstMatch
        guard overview.waitForExistence(timeout: 3) else {
            XCTFail("Accessibility Visit overview did not appear")
            return
        }
        XCTAssertTrue(overview.isHittable)
        let overviewText = accessibilityText(of: overview)
        XCTAssertTrue(overviewText.contains("Completed"))
        XCTAssertTrue(overviewText.contains("invoiced work"))
        XCTAssertTrue(overviewText.contains("can no longer be corrected"))

        let serviceLocation = app.descendants(matching: .any)[
            "visit-detail-service-location-snapshot"
        ].firstMatch
        XCTAssertTrue(serviceLocation.waitForExistence(timeout: 3))
        XCTAssertTrue(serviceLocation.isHittable)
        XCTAssertTrue(
            accessibilityText(of: serviceLocation).contains(
                "Invoice Service Location"
            )
        )
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Visit history accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let horseResult = app.descendants(matching: .any)[
            "visit-result-Milo"
        ].firstMatch
        XCTAssertTrue(bringIntoView(horseResult, in: app))
    }

    @MainActor
    func testDefaultInvoicedVisitKeepsDetailedSummary() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "VisitHistoryDefault-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "payment-pending"
        app.launch()
        defer { app.terminate() }

        guard openInvoicedVisit(in: app) else { return }

        let status = app.staticTexts["visit-detail-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: status).contains("Completed"))
        XCTAssertTrue(
            app.staticTexts[
                "This visit has invoiced work and can no longer be corrected."
            ].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "visit-detail-accessibility-overview"
            ].exists
        )

        let serviceLocation = app.descendants(matching: .any)[
            "visit-detail-service-location-snapshot"
        ].firstMatch
        XCTAssertTrue(serviceLocation.waitForExistence(timeout: 3))
        XCTAssertTrue(serviceLocation.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Visit history default Dynamic Type"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func openInvoicedVisit(in app: XCUIApplication) -> Bool {
        guard openClients(in: app) else {
            XCTFail("Clients tab did not open")
            return false
        }
        let client = app.buttons["client-row-Invoice Client"]
        guard client.waitForExistence(timeout: 5) else {
            XCTFail("Invoice Client did not appear")
            return false
        }
        client.tap()

        let horse = app.buttons["horse-row-Milo"]
        guard horse.waitForExistence(timeout: 3) else {
            XCTFail("Milo did not appear")
            return false
        }
        horse.tap()

        let history = app.descendants(matching: .any)[
            "horse-history-visit-Milo"
        ].firstMatch
        guard bringIntoView(history, in: app) else {
            XCTFail("Milo's Visit history did not appear")
            return false
        }
        history.tap()

        guard app.navigationBars["Visit"].waitForExistence(timeout: 3) else {
            XCTFail("Visit detail did not open")
            return false
        }
        return true
    }

    @MainActor
    private func openClients(in app: XCUIApplication) -> Bool {
        for _ in 0..<3 {
            app.tabBars.buttons["Clients"].tap()
            if app.buttons["More"].waitForExistence(timeout: 2) {
                return true
            }
        }
        return false
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

    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
