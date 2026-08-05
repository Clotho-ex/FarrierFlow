import XCTest

final class OwnerSetupUITests: XCTestCase {
    @MainActor
    func testIdentitySetupPersistsAndOpensToday() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetup-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launch()
        defer { app.terminate() }

        let name = app.textFields["business-profile-name-field"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["business-profile-phone-field"].exists)
        XCTAssertFalse(app.textFields["business-profile-email-field"].exists)
        XCTAssertFalse(app.textFields["business-profile-address-field"].exists)
        name.tap()
        name.typeText("Carter Field Farrier")
        app.buttons["business-profile-save-action"].tap()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["business-profile-name-field"].exists)
    }

    @MainActor
    func testFirstCustomerFlowReachesInvoiceReadyAndPersists() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "FarrierActivation-\(UUID().uuidString)"
        app.launchEnvironment["TZ"] = "America/Los_Angeles"
        app.launch()
        defer { app.terminate() }

        let serviceName = "Trim"
        let locationName = "North Field"
        let locationAddress = "24 Stable Lane"
        let arrivalNotes = "Use Gate 4 and park beside the arena."
        let clientName = "Megan Brooks"
        let horseName = "Copper"

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let addFirstClient = app.buttons["today-add-first-client"]
        XCTAssertTrue(addFirstClient.waitForExistence(timeout: 3))
        addFirstClient.tap()
        focusAndType(clientName, in: app.textFields["client-name-field"], app: app)
        app.buttons["Save"].tap()

        let schedule = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 3))
        schedule.tap()
        let addLocation = app.buttons["appointment-add-service-location"]
        XCTAssertTrue(addLocation.waitForExistence(timeout: 3))
        addLocation.tap()
        focusAndType(locationName, in: app.textFields["barn-name-field"], app: app)
        app.buttons["barn-more-details"].tap()
        focusAndType(locationAddress, in: app.textFields["Address"], app: app)
        focusAndType(arrivalNotes, in: app.textViews["Contact Notes"], app: app)
        app.navigationBars["New Service Location"].buttons["Save"].tap()
        XCTAssertTrue(
            accessibilityText(of: app.buttons["appointment-barn-picker"])
                .contains(locationName)
        )

        let addHorse = app.buttons["appointment-add-horse"]
        tapAfterBringingIntoView(addHorse, in: app)
        let horseNameField = app.textFields["horse-name-field"]
        XCTAssertTrue(horseNameField.waitForExistence(timeout: 3))
        horseNameField.tap()
        horseNameField.typeText(horseName)
        app.buttons["horse-client-picker"].tap()
        app.buttons[clientName].tap()
        app.navigationBars["New Horse"].buttons["Save"].tap()

        XCTAssertTrue(
            accessibilityText(of: app.buttons["appointment-barn-picker"])
                .contains(locationName)
        )
        app.navigationBars["New Appointment"].buttons["Save"].tap()

        let scheduledStop = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(scheduledStop.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: scheduledStop).contains(locationAddress))
        scheduledStop.tap()
        let detailAddress = app.descendants(matching: .any)[
            "appointment-detail-address"
        ]
        XCTAssertTrue(detailAddress.waitForExistence(timeout: 3))
        XCTAssertTrue(accessibilityText(of: detailAddress).contains(locationAddress))
        let detailArrivalNotes = app.descendants(matching: .any)[
            "appointment-detail-arrival-notes"
        ]
        XCTAssertTrue(bringIntoView(detailArrivalNotes, in: app))
        XCTAssertTrue(accessibilityText(of: detailArrivalNotes).contains(arrivalNotes))

        tapAfterBringingIntoView(app.buttons["visit-start-action"], in: app)
        selectServicedOutcome(for: horseName, in: app)
        tapAfterBringingIntoView(
            app.buttons["visit-add-service-\(horseName)"],
            in: app
        )
        let createService = app.buttons["visit-create-service-action"]
        XCTAssertTrue(createService.waitForExistence(timeout: 3))
        createService.tap()
        focusAndType(serviceName, in: app.textFields["service-name-field"], app: app)
        focusAndType("65.00", in: app.textFields["service-price-field"], app: app)
        app.navigationBars["New Service"].buttons["Save"].tap()
        XCTAssertTrue(
            app.buttons["visit-work-item-\(horseName)-\(serviceName)"]
                .waitForExistence(timeout: 3)
        )
        let completeVisit = app.buttons["visit-complete"]
        XCTAssertTrue(completeVisit.waitForExistence(timeout: 3))
        let enabled = expectation(
            for: NSPredicate(format: "isEnabled == true"),
            evaluatedWith: completeVisit
        )
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 3), .completed)
        completeVisit.tap()

        XCTAssertTrue(app.navigationBars["Next Appointment"].waitForExistence(timeout: 5))
        app.buttons["Not Now"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready to Invoice"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Create Invoice")
        ).firstMatch.exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ready to Invoice"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func selectServicedOutcome(
        for horseName: String,
        in app: XCUIApplication
    ) {
        let picker = app.buttons["visit-outcome-\(horseName)"]
        tapAfterBringingIntoView(picker, in: app)
        let serviced = app.buttons["Serviced"].firstMatch
        XCTAssertTrue(serviced.waitForExistence(timeout: 3))
        serviced.tap()
    }

    @MainActor
    private func focusAndType(
        _ text: String,
        in element: XCUIElement,
        app: XCUIApplication
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        tapAfterBringingIntoView(element, in: app)
        element.typeText(text)
    }

    @MainActor
    private func tapAfterBringingIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        guard bringIntoView(element, in: app), element.isHittable else {
            XCTFail("Expected element to become visible and hittable")
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    private func bringIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<5 {
            let visibleFrame = unobscuredFrame(in: app)
            if element.exists,
               visibleFrame.contains(
                   CGPoint(x: element.frame.midX, y: element.frame.midY)
               ) {
                return true
            }
            if element.exists, element.frame.midY < visibleFrame.minY {
                scrollForm(in: app, upward: false)
            } else {
                scrollForm(in: app, upward: true)
            }
        }
        let visibleFrame = unobscuredFrame(in: app)
        return element.exists
            && visibleFrame.contains(
                CGPoint(x: element.frame.midX, y: element.frame.midY)
            )
    }

    @MainActor
    private func unobscuredFrame(in app: XCUIApplication) -> CGRect {
        let appFrame = app.frame
        let keyboard = app.keyboards.firstMatch
        let bottom = keyboard.exists ? keyboard.frame.minY : appFrame.maxY
        return CGRect(
            x: appFrame.minX,
            y: appFrame.minY + 100,
            width: appFrame.width,
            height: max(0, bottom - appFrame.minY - 120)
        )
    }

    @MainActor
    private func scrollForm(in app: XCUIApplication, upward: Bool) {
        let form = app.collectionViews.firstMatch
        if form.exists {
            if upward {
                form.swipeUp()
            } else {
                form.swipeDown()
            }
        } else {
            if upward {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
        }
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
