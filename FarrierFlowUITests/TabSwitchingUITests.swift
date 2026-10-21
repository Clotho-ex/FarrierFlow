import XCTest

final class TabSwitchingUITests: XCTestCase {
    @MainActor
    func testTabSwitchesKeepToolbarActionsAndIndependentHistory() {
        verifyTabSwitching(largestText: false)
    }

    @MainActor
    func testTabSwitchesAtLargestTextInDarkMode() {
        verifyTabSwitching(largestText: true)
    }

    @MainActor
    private func verifyTabSwitching(largestText: Bool) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = "TabSwitching-\(UUID())"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "full"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largestText {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        }
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Today"].buttons["Schedule Appointment"].exists)
        selectTab("Schedule", in: app)
        XCTAssertTrue(app.tabBars.buttons["Schedule"].isSelected, app.debugDescription)
        XCTAssertTrue(app.navigationBars["Schedule"].waitForExistence(timeout: 3), app.debugDescription)
        openAndCancelEditor("Schedule Appointment", title: "New Appointment", in: app)

        let appointment = app.buttons["appointment-row-Willow Creek Stables"].firstMatch
        XCTAssertTrue(appointment.waitForExistence(timeout: 3))
        appointment.tap()
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        selectTab("Clients", in: app)
        openAndCancelEditor("Add Client", title: "New Client", in: app)
        XCTAssertFalse(app.buttons["More"].exists)
        let client = app.buttons["client-row-Jordan Ellis"]
        XCTAssertTrue(client.waitForExistence(timeout: 3))
        client.tap()
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        app.openBusinessRoot()
        app.buttons["Service Locations"].tap()
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 3))

        selectTab("Today", in: app)
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected, app.debugDescription)
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3), app.debugDescription)
        selectTab("Schedule", in: app)
        XCTAssertTrue(app.navigationBars["Appointment"].waitForExistence(timeout: 3))
        app.navigationBars["Appointment"].buttons["Schedule"].tap()
        selectTab("Clients", in: app)
        XCTAssertTrue(app.navigationBars["Client"].waitForExistence(timeout: 3))
        app.navigationBars["Client"].buttons["Clients"].tap()
        selectTab("Business", in: app)
        XCTAssertTrue(app.navigationBars["Service Locations"].waitForExistence(timeout: 3))
        app.navigationBars["Service Locations"].buttons["Business"].tap()

        for _ in 0..<2 {
            for title in ["Today", "Schedule", "Clients", "Business"] {
                selectTab(title, in: app)
                XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
                if title == "Business" {
                    XCTAssertTrue(app.buttons["Services"].isHittable)
                    continue
                }
                if title == "Today" {
                    XCTAssertFalse(app.navigationBars[title].buttons["Schedule Appointment"].exists)
                    continue
                }
                let action = title == "Clients" ? "Add Client" : "Schedule Appointment"
                XCTAssertEqual(app.navigationBars[title].buttons.matching(identifier: action).count, 1)
                XCTAssertTrue(app.buttons[action].isHittable)
                if title == "Clients" { XCTAssertFalse(app.buttons["More"].exists) }
            }
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = largestText ? "Tabs largest text dark" : "Tabs standard text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func selectTab(_ title: String, in app: XCUIApplication) {
        app.selectFarrierFlowTab(title)
    }

    @MainActor
    private func openAndCancelEditor(_ action: String, title: String, in app: XCUIApplication) {
        let button = app.buttons[action].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
        app.navigationBars[title].buttons["Cancel"].tap()
    }
}
