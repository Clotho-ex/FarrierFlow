import XCTest

final class RootNavigationUITests: XCTestCase {
    @MainActor
    func testRootTabsAndClientNavigationPersistIndependently() throws {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "RootNavigation-\(UUID().uuidString)"
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
        XCTAssertTrue(app.tabBars.buttons["Schedule"].exists)
        XCTAssertTrue(app.tabBars.buttons["Clients"].exists)

        app.tabBars.buttons["Clients"].tap()
        XCTAssertTrue(app.navigationBars["Clients"].waitForExistence(timeout: 2))
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Service Locations"].exists)
        XCTAssertFalse(app.buttons["Settings"].exists)
        app.buttons["Service Locations"].tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Clients"].tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 2))
    }
}
