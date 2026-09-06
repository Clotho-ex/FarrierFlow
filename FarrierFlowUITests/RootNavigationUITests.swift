import XCTest

final class RootNavigationUITests: XCTestCase {
    @MainActor
    func testShowcaseVisitEditorLabelsHoofPhotosOnce() {
        let app = launchShowcase(storeName: "VisitEditorPhotographs")
        defer { app.terminate() }

        let activeVisit = app.buttons["today-run-sheet-active"]
        XCTAssertTrue(activeVisit.waitForExistence(timeout: 5))
        activeVisit.tap()
        XCTAssertTrue(app.navigationBars["Visit"].waitForExistence(timeout: 3))

        let photographs = app.buttons["visit-photographs-Atlas"].firstMatch
        for _ in 0..<4 where !photographs.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(photographs.waitForExistence(timeout: 3))
        let visibleLabel = app.descendants(matching: .any)[
            "visit-photographs-label-Atlas"
        ].firstMatch
        XCTAssertTrue(
            visibleLabel.waitForExistence(timeout: 3),
            "The Visit editor should visibly label the photograph row."
        )
        XCTAssertEqual(
            photographs.label.components(separatedBy: "Hoof Photos").count - 1,
            1,
            "The Visit editor should show exactly one Hoof Photos label before its count."
        )
    }

    @MainActor
    func testRootTabsLeaveBreathingRoomBelowToolbar() {
        let app = launchShowcase(storeName: "RootContentSpacing")
        defer { app.terminate() }

        assertContentStartsBelowToolbar(
            tab: "Today",
            content: app.staticTexts["Northline Farrier Service"].firstMatch,
            minimumGap: 57,
            in: app
        )
        let todayIdentity = app.staticTexts["Northline Farrier Service"].firstMatch
        let todayAction = app.buttons["today-run-sheet-active"].firstMatch
        XCTAssertTrue(todayAction.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(
            todayAction.frame.minY - todayIdentity.frame.maxY,
            52,
            "Today should keep a standard section rhythm between identity and action."
        )
        assertContentStartsBelowToolbar(
            tab: "Schedule",
            content: app.descendants(matching: .any)[
                "appointment-row-Willow Creek Stables"
            ].firstMatch,
            minimumGap: 47,
            in: app
        )
        assertContentStartsBelowToolbar(
            tab: "Clients",
            content: app.descendants(matching: .any)["client-row-Jordan Ellis"].firstMatch,
            minimumGap: 114,
            in: app
        )
    }

    @MainActor
    func testRootTabsRemainReadableAtAccessibilityXXXL() {
        let app = launchShowcase(
            storeName: "RootAccessibilitySpacing",
            accessibilityXXXL: true
        )
        defer { app.terminate() }

        assertVisibleRootContent(
            tab: "Today",
            content: app.buttons["today-run-sheet-active"].firstMatch,
            in: app
        )
        assertVisibleRootContent(
            tab: "Schedule",
            content: app.descendants(matching: .any)[
                "appointment-row-Willow Creek Stables"
            ].firstMatch,
            in: app
        )
        assertVisibleRootContent(
            tab: "Clients",
            content: app.descendants(matching: .any)["client-row-Jordan Ellis"].firstMatch,
            in: app
        )
    }

    @MainActor
    func testRootTabTitlesShareToolbarRowAtRegularTextSize() {
        let app = launchShowcase(storeName: "RootInlineLargeTitles")
        defer { app.terminate() }

        assertToolbarTitle("Today", actionLabel: "Schedule Appointment", in: app)
        assertToolbarTitle("Schedule", actionLabel: "Schedule Appointment", in: app)
        assertToolbarTitle("Clients", actionLabel: "Add Client", in: app)
    }

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

    @MainActor
    private func launchShowcase(
        storeName: String,
        accessibilityXXXL: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "\(storeName)-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "app-store-showcase"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "full"
        if accessibilityXXXL {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
            app.launchArguments = [
                "-AppleLanguages", "(en)",
                "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            ]
        } else {
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        }
        app.launch()
        return app
    }

    @MainActor
    private func assertToolbarTitle(
        _ title: String,
        actionLabel: String,
        in app: XCUIApplication
    ) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()

        let navigationBar = app.navigationBars[title]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
        let titleLabel = navigationBar.staticTexts[title].firstMatch
        let action = app.buttons[actionLabel].firstMatch
        XCTAssertTrue(titleLabel.waitForExistence(timeout: 3))
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        XCTAssertEqual(
            titleLabel.frame.midY,
            action.frame.midY,
            accuracy: 12,
            "\(title) should share the compact toolbar row with its primary action."
        )
    }

    @MainActor
    private func assertContentStartsBelowToolbar(
        tab: String,
        content: XCUIElement,
        minimumGap: CGFloat,
        in app: XCUIApplication
    ) {
        let tabButton = app.tabBars.buttons[tab]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()

        let navigationBar = app.navigationBars[tab]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
        XCTAssertTrue(content.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(
            content.frame.minY - navigationBar.frame.maxY,
            minimumGap,
            "\(tab) should keep at least \(minimumGap) points between its toolbar and first record."
        )
    }

    @MainActor
    private func assertVisibleRootContent(
        tab: String,
        content: XCUIElement,
        in app: XCUIApplication
    ) {
        let tabButton = app.tabBars.buttons[tab]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
        XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 3))
        XCTAssertTrue(content.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.frame.intersects(content.frame),
            "\(tab) should keep its first record visible at Accessibility XXXL."
        )
    }
}
