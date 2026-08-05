import XCTest

final class NextAppointmentFlowUITests: XCTestCase {
    private let clientName = "Next Appointment Client"
    private let barnName = "Next Appointment Service Location"
    private let earliestHorseName = "Atlas"
    private let laterHorseName = "Beacon"
    private let notServicedHorseName = "Clover"

    @MainActor
    func testThreeHorseSubsetSavePersistsAndReopensAsPartialDuplicate() throws {
        let app = launch(storeName: "NextAppointment-\(UUID().uuidString)")
        defer { app.terminate() }

        openSourceVisit(for: earliestHorseName, in: app)
        let schedule = app.buttons["schedule-next-appointment"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 5))
        schedule.tap()

        assertInitialProjection(in: app)
        let initialStart = proposedStartValue(in: app)

        app.buttons["Not Now"].tap()
        XCTAssertTrue(schedule.waitForExistence(timeout: 5))
        app.tabBars.buttons["Schedule"].tap()
        XCTAssertEqual(appointmentRows(in: app).count, 0)

        openSourceVisit(for: earliestHorseName, in: app)
        app.buttons["schedule-next-appointment"].tap()
        XCTAssertTrue(app.navigationBars["Next Appointment"].waitForExistence(timeout: 5))

        setHorse(earliestHorseName, selected: false, in: app)
        let recalculatedStart = waitForProposedStartChange(from: initialStart, in: app)
        XCTAssertNotEqual(recalculatedStart, initialStart)

        setProposedTime(toHour: "10", in: app)
        let overriddenStart = proposedStartValue(in: app)
        setHorse(notServicedHorseName, selected: true, in: app)
        XCTAssertEqual(proposedStartValue(in: app), overriddenStart)

        app.buttons["next-appointment-continue"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            accessibilityText(of: app.buttons["appointment-barn-picker"])
                .contains(barnName)
        )
        assertAppointmentSelection(earliestHorseName, selected: false, in: app)
        assertAppointmentSelection(laterHorseName, selected: true, in: app)
        assertAppointmentSelection(notServicedHorseName, selected: true, in: app)
        app.navigationBars["New Appointment"].buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars[barnName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells.staticTexts[laterHorseName].exists)
        XCTAssertTrue(app.cells.staticTexts[notServicedHorseName].exists)

        app.terminate()
        app.launch()

        app.tabBars.buttons["Schedule"].tap()
        XCTAssertEqual(appointmentRows(in: app).count, 1)
        openSourceVisit(for: earliestHorseName, in: app)
        app.buttons["schedule-next-appointment"].tap()
        XCTAssertTrue(app.navigationBars["Next Appointment"].waitForExistence(timeout: 5))

        assertHorse(
            earliestHorseName,
            contains: ["Serviced", "Selected", "Suggested"],
            excludes: ["Already Scheduled"],
            in: app
        )
        assertHorse(
            laterHorseName,
            contains: ["Serviced", "Already Scheduled"],
            excludes: ["Selected"],
            in: app
        )
        assertHorse(
            notServicedHorseName,
            contains: ["Not Serviced", "Already Scheduled"],
            excludes: ["Selected", "Suggested"],
            in: app
        )
        let continueButton = app.buttons["next-appointment-continue"]
        XCTAssertTrue(bringIntoView(continueButton, in: app))
        XCTAssertTrue(continueButton.isEnabled)
    }

    @MainActor
    private func launch(storeName: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] = storeName
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "next-appointment"
        app.launchEnvironment["TZ"] = "America/New_York"
        app.launch()
        return app
    }

    @MainActor
    private func openSourceVisit(
        for horseName: String,
        in app: XCUIApplication
    ) {
        if app.navigationBars["Visit"].exists,
           bringIntoView(app.buttons["schedule-next-appointment"], in: app) {
            return
        }
        app.tabBars.buttons["Clients"].tap()
        if app.navigationBars["Visit"].exists,
           bringIntoView(app.buttons["schedule-next-appointment"], in: app) {
            return
        }
        let client = app.staticTexts["client-row-\(clientName)"]
        XCTAssertTrue(client.waitForExistence(timeout: 5))
        client.tap()
        let horse = app.staticTexts["horse-row-\(horseName)"]
        XCTAssertTrue(horse.waitForExistence(timeout: 5))
        horse.tap()
        let history = app.descendants(matching: .any)[
            "horse-history-visit-\(horseName)"
        ]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(
            bringIntoView(app.buttons["schedule-next-appointment"], in: app)
        )
    }

    @MainActor
    private func bringIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<6 {
            if element.exists, element.isHittable {
                return true
            }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func assertInitialProjection(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Next Appointment"].waitForExistence(timeout: 5))
        assertHorse(
            earliestHorseName,
            contains: ["Serviced", "4 weeks", "Suggested", "Selected"],
            excludes: ["Already Scheduled"],
            in: app
        )
        assertHorse(
            laterHorseName,
            contains: ["Serviced", "6 weeks", "Suggested", "Selected"],
            excludes: ["Already Scheduled"],
            in: app
        )
        assertHorse(
            notServicedHorseName,
            contains: ["Not Serviced", "Not selected"],
            excludes: ["Suggested", "Selected"],
            in: app
        )
        XCTAssertTrue(app.buttons["next-appointment-continue"].isEnabled)
    }

    @MainActor
    private func assertHorse(
        _ name: String,
        contains expected: [String],
        excludes unexpected: [String],
        in app: XCUIApplication
    ) {
        let row = app.descendants(matching: .any)["next-appointment-horse-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let text = accessibilityText(of: row)
        for value in expected {
            XCTAssertTrue(text.contains(value), "Expected \(name) to contain \(value): \(text)")
        }
        for value in unexpected {
            XCTAssertFalse(text.contains(value), "Expected \(name) to exclude \(value): \(text)")
        }
    }

    @MainActor
    private func setHorse(
        _ name: String,
        selected: Bool,
        in app: XCUIApplication
    ) {
        let row = app.descendants(matching: .any)["next-appointment-horse-\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let selectionChanged = expectation(
            for: NSPredicate { evaluated, _ in
                guard let element = evaluated as? XCUIElement else { return false }
                let text = self.accessibilityText(of: element)
                return selected ? text.contains("Selected") : text.contains("Not selected")
            },
            evaluatedWith: row
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [selectionChanged], timeout: 5),
            .completed
        )
    }

    @MainActor
    private func proposedStartValue(in app: XCUIApplication) -> String {
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        return datePickerValue(of: picker)
    }

    @MainActor
    private func waitForProposedStartChange(
        from original: String,
        in app: XCUIApplication
    ) -> String {
        let picker = app.datePickers.firstMatch
        let changed = expectation(
            for: NSPredicate { evaluated, _ in
                guard let element = evaluated as? XCUIElement else { return false }
                return self.datePickerValue(of: element) != original
            },
            evaluatedWith: picker
        )
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed)
        return datePickerValue(of: picker)
    }

    @MainActor
    private func setProposedTime(toHour hour: String, in app: XCUIApplication) {
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let buttons = picker.descendants(matching: .button)
        XCTAssertGreaterThan(buttons.count, 0)
        buttons.element(boundBy: buttons.count - 1).tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: hour)
        app.navigationBars["Next Appointment"].tap()
        XCTAssertTrue(wheel.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func datePickerValue(of picker: XCUIElement) -> String {
        let buttons = picker.descendants(matching: .button)
        return (0..<buttons.count)
            .map { accessibilityText(of: buttons.element(boundBy: $0)) }
            .joined(separator: " ")
    }

    @MainActor
    private func assertAppointmentSelection(
        _ horseName: String,
        selected: Bool,
        in app: XCUIApplication
    ) {
        let row = app.buttons["appointment-horse-\(horseName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(accessibilityText(of: row).contains("Selected"), selected)
    }

    @MainActor
    private func appointmentRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.staticTexts.matching(identifier: "appointment-row-\(barnName)")
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
