import XCTest

final class FormatterDisplayUITests: XCTestCase {
    @MainActor
    func testExtremeDurationAndWeekPluralizationRenderInDetails() throws {
        let clientName = "Formatter Client"
        let barnName = "Formatter Barn"
        let horseName = "Formatter Horse"
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "FormatterDisplay-\(UUID().uuidString)"
        app.launch()

        app.tabBars.buttons["Clients"].tap()
        app.buttons["Add Client"].firstMatch.tap()
        app.textFields["client-name-field"].tap()
        app.textFields["client-name-field"].typeText(clientName)
        app.buttons["Save"].tap()

        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Service Locations"].waitForExistence(timeout: 3))
        app.buttons["Service Locations"].tap()
        app.buttons["Add Service Location"].firstMatch.tap()
        app.textFields["barn-name-field"].tap()
        app.textFields["barn-name-field"].typeText(barnName)
        app.buttons["Save"].tap()
        app.navigationBars.buttons["Clients"].tap()

        app.staticTexts["client-row-\(clientName)"].tap()
        app.buttons["Add Horse"].tap()
        app.textFields["horse-name-field"].tap()
        app.textFields["horse-name-field"].typeText(horseName)
        app.buttons["horse-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["Save"].tap()
        app.staticTexts["horse-row-\(horseName)"].tap()

        let interval = app.descendants(matching: .any)[
            "horse-detail-appointment-interval"
        ]
        XCTAssertTrue(interval.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: interval).contains("6 weeks"))

        app.buttons["Edit"].tap()
        let decrement = app.steppers.firstMatch.buttons["Decrement"]
        XCTAssertTrue(decrement.waitForExistence(timeout: 3))
        for _ in 0..<5 {
            decrement.tap()
        }
        app.buttons["Save"].tap()
        XCTAssertTrue(interval.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: interval).contains("1 week"))

        app.tabBars.buttons["Today"].tap()
        app.buttons["Schedule Appointment"].firstMatch.tap()
        app.buttons["appointment-barn-picker"].tap()
        app.buttons[barnName].tap()
        app.buttons["appointment-horse-\(horseName)"].tap()
        let durationField = app.textFields["Expected Duration (minutes)"]
        durationField.tap()
        durationField.typeText(String(Int.max))
        app.buttons["Save"].tap()
        app.staticTexts["appointment-row-\(barnName)"].tap()

        let duration = app.descendants(matching: .any)[
            "appointment-detail-expected-duration"
        ]
        XCTAssertTrue(duration.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: duration).contains("minutes"))
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
