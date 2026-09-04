import CoreImage
import UIKit
import XCTest

final class OwnerSetupUITests: XCTestCase {
    @MainActor
    func testBriefingStartsFlowAndBusinessPrecedesSubscription() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupBriefingFirst-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        let briefing = app.descendants(matching: .any)["onboarding-welcome"]
        XCTAssertTrue(briefing.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Run your business from the field."].exists)
        XCTAssertFalse(app.textFields["business-profile-name-field"].exists)

        let getStarted = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(getStarted))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            getStarted,
            destination: name,
            in: app
        ) else { return }

        XCTAssertTrue(
            app.staticTexts["Start with the name your clients know and trust."]
                .exists
        )

        focusAndType("Carter Field Farrier", in: name, app: app)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }

        guard tapUntilDestinationAppears(
            app.buttons["business-profile-save-action"],
            destination: app.navigationBars["FarrierFlow Pro"],
            in: app
        ) else { return }

        XCTAssertFalse(app.buttons["subscription-continue-read-only"].exists)
    }

    @MainActor
    func testIdentitySetupPersistsAndOpensToday() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetup-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launch()
        defer { app.terminate() }

        let getStarted = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(getStarted))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            getStarted,
            destination: name,
            in: app
        ) else { return }
        XCTAssertFalse(app.staticTexts["Step 1 of 3"].exists)
        XCTAssertFalse(app.textFields["business-profile-phone-field"].exists)
        XCTAssertFalse(app.textFields["business-profile-email-field"].exists)
        XCTAssertFalse(app.textFields["business-profile-address-field"].exists)
        XCTAssertFalse(app.buttons["business-profile-save-action"].isEnabled)
        for _ in 0..<2 where !app.keyboards.firstMatch.exists {
            name.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        name.typeText("Carter Field Farrier")
        XCTAssertTrue(app.buttons["business-profile-save-action"].isEnabled)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertFalse(
            app.buttons["Done"].exists,
            "Onboarding should rely on the native Return/Go key, not a custom keyboard toolbar."
        )
        name.typeText("\n")
        let today = app.navigationBars["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["business-profile-name-field"].exists)
    }

    @MainActor
    func testNativeBackNavigationPersistsReturnedBriefingStep() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupBackNavigation-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launch()
        defer { app.terminate() }

        let getStarted = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(getStarted))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            getStarted,
            destination: name,
            in: app
        ) else { return }
        focusAndType("Carter Field Farrier", in: name, app: app)
        let done = app.buttons["Done"]
        if done.exists {
            done.tap()
        }

        let subscription = app.navigationBars["FarrierFlow Pro"]
        guard tapUntilDestinationAppears(
            app.buttons["business-profile-save-action"],
            destination: subscription,
            in: app
        ) else { return }

        let back = subscription.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        app.navigationBars["Your Business"].buttons.firstMatch.tap()
        XCTAssertTrue(getStarted.waitForExistence(timeout: 3))

        app.terminate()
        app.launch()

        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        XCTAssertFalse(name.exists)
    }

    @MainActor
    func testInterruptedSubscriptionReconstructsNativeStack() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupStackResume-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        let getStarted = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(getStarted))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            getStarted,
            destination: name,
            in: app
        ) else { return }
        focusAndType("Carter Field Farrier", in: name, app: app)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }

        let subscription = app.navigationBars["FarrierFlow Pro"]
        guard tapUntilDestinationAppears(
            app.buttons["business-profile-save-action"],
            destination: subscription,
            in: app
        ) else { return }

        app.terminate()
        app.launch()
        XCTAssertTrue(subscription.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["subscription-continue-read-only"].exists)
        XCTAssertFalse(getStarted.exists)

        subscription.buttons.firstMatch.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "Carter Field Farrier")
    }

    @MainActor
    func testInterruptedOnboardingResumesAtBusinessSetup() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupResume-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launch()
        defer { app.terminate() }

        let getStarted = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(getStarted))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            getStarted,
            destination: name,
            in: app
        ) else { return }

        app.terminate()
        app.launch()

        XCTAssertTrue(
            app.textFields["business-profile-name-field"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(getStarted.exists)
    }

    @MainActor
    func testWelcomeSupportsAccessibilityExtraExtraExtraLarge() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupAccessibility-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"] = "accessibility5"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launch()
        defer { app.terminate() }

        let briefingContinue = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(briefingContinue))
        let brandTitle = app.staticTexts["onboarding-welcome"]
        XCTAssertTrue(bringIntoView(brandTitle, in: app))
        XCTAssertTrue(bringIntoView(briefingContinue, in: app))

        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            briefingContinue,
            destination: name,
            in: app
        ) else { return }
        guard bringIntoView(name, in: app) else {
            XCTFail("Business name field should be reachable at accessibility XXXL")
            return
        }
        focusAndType("Accessible Farrier", in: name, app: app)
        let done = app.buttons["Done"]
        if done.exists {
            done.tap()
        }

        let businessContinue = app.buttons["business-profile-save-action"]
        XCTAssertTrue(businessContinue.waitForExistence(timeout: 3))
        XCTAssertTrue(businessContinue.isHittable)

        let subscriptionTitle = app.navigationBars["FarrierFlow Pro"]
        guard tapUntilDestinationAppears(
            businessContinue,
            destination: subscriptionTitle,
            in: app
        ) else { return }
        XCTAssertTrue(
            app.staticTexts["Create and edit your business records."].exists
        )
        XCTAssertTrue(bringIntoView(app.buttons["subscription-plan-monthly"], in: app))
        XCTAssertTrue(bringIntoView(app.buttons["subscription-plan-annual"], in: app))
        app.buttons["subscription-plan-monthly"].tap()
        XCTAssertTrue(
            bringIntoView(app.buttons["subscription-primary-purchase"], in: app)
        )
    }

    @MainActor
    func testSimplifiedOnboardingRemainsReachableInLandscape() {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }

        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupLandscape-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        app.launch()
        defer { app.terminate() }

        let briefingContinue = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(briefingContinue))
        XCTAssertTrue(bringIntoView(briefingContinue, in: app))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            briefingContinue,
            destination: name,
            in: app
        ) else { return }
        focusAndType("Landscape Farrier", in: name, app: app)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }

        let businessContinue = app.buttons["business-profile-save-action"]
        guard tapUntilDestinationAppears(
            businessContinue,
            destination: app.navigationBars["FarrierFlow Pro"],
            in: app
        ) else { return }

        XCTAssertTrue(bringIntoView(app.buttons["subscription-primary-purchase"], in: app))
        XCTAssertFalse(app.buttons["subscription-continue-read-only"].exists)
    }

    @MainActor
    func testSimplifiedOnboardingVisualSequence() {
        runSimplifiedOnboardingVisualSequence(colorScheme: nil)
    }

    @MainActor
    func testSimplifiedOnboardingVisualSequenceInDarkMode() {
        runSimplifiedOnboardingVisualSequence(colorScheme: "dark")
    }

    @MainActor
    private func runSimplifiedOnboardingVisualSequence(
        colorScheme: String?
    ) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupVisualSequence-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] = "read-only"
        if let colorScheme {
            app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = colorScheme
        }
        app.launch()
        defer { app.terminate() }

        let briefingContinue = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(briefingContinue))
        keepScreenshot(named: "01-FarrierFlow", of: app)

        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            briefingContinue,
            destination: name,
            in: app
        ) else { return }
        keepScreenshot(named: "02-Business", of: app)

        focusAndType("Carter Field Farrier", in: name, app: app)
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }
        guard tapUntilDestinationAppears(
            app.buttons["business-profile-save-action"],
            destination: app.navigationBars["FarrierFlow Pro"],
            in: app
        ) else { return }
        keepScreenshot(named: "03-Subscription", of: app)
    }

    @MainActor
    func testWelcomeWorkflowUsesOneEqualVerticalWorkline() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupVerticalWorkflow-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.buttons["onboarding-briefing-continue"].waitForExistence(timeout: 5)
        )

        let appointment = app.descendants(matching: .any)["onboarding-workflow-appointment"]
        let visit = app.descendants(matching: .any)["onboarding-workflow-visit"]
        let invoice = app.descendants(matching: .any)["onboarding-workflow-invoice"]
        let payment = app.descendants(matching: .any)["onboarding-workflow-payment"]
        XCTAssertTrue(app.staticTexts["Keep every job connected."].waitForExistence(timeout: 3))
        let supportingText = app.staticTexts["Run your business from the field."]
        let worklineTitle = app.staticTexts["Keep every job connected."]
        XCTAssertGreaterThanOrEqual(
            worklineTitle.frame.minY - supportingText.frame.maxY,
            40,
            "The product statement and workline need a clear section break."
        )
        XCTAssertTrue(appointment.waitForExistence(timeout: 3))
        XCTAssertTrue(visit.waitForExistence(timeout: 3))
        XCTAssertTrue(invoice.waitForExistence(timeout: 3))
        XCTAssertTrue(payment.waitForExistence(timeout: 3))
        XCTAssertEqual(appointment.label, "Appointment. Plan the next stop. 1 of 4.")
        XCTAssertEqual(visit.label, "Visit. Capture the work. 2 of 4.")
        XCTAssertEqual(invoice.label, "Invoice. Bill while it’s fresh. 3 of 4.")
        XCTAssertEqual(payment.label, "Payment. Know what’s settled. 4 of 4.")

        let appointmentTitle = app.staticTexts["Appointment"]
        let visitTitle = app.staticTexts["Visit"]
        let invoiceTitle = app.staticTexts["Invoice"]
        let paymentTitle = app.staticTexts["Payment"]
        XCTAssertLessThan(appointmentTitle.frame.midY, visitTitle.frame.midY)
        XCTAssertLessThan(visitTitle.frame.midY, invoiceTitle.frame.midY)
        XCTAssertLessThan(invoiceTitle.frame.midY, paymentTitle.frame.midY)
        XCTAssertLessThan(
            app.staticTexts["Plan the next stop."].frame.maxY,
            visitTitle.frame.minY,
            "Appointment supporting copy must not overlap Visit."
        )
        XCTAssertLessThan(
            app.staticTexts["Capture the work."].frame.maxY,
            invoiceTitle.frame.minY,
            "Visit supporting copy must not overlap Invoice."
        )
        XCTAssertLessThan(
            app.staticTexts["Bill while it’s fresh."].frame.maxY,
            paymentTitle.frame.minY,
            "Invoice supporting copy must not overlap Payment."
        )
        XCTAssertEqual(appointmentTitle.frame.minX, visitTitle.frame.minX, accuracy: 2)
        XCTAssertEqual(visitTitle.frame.minX, invoiceTitle.frame.minX, accuracy: 2)
        XCTAssertEqual(invoiceTitle.frame.minX, paymentTitle.frame.minX, accuracy: 2)
    }

    @MainActor
    func testOnboardingUsesCompactNativeConfirmationActions() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupActionGeometry-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        let briefingContinue = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(briefingContinue))
        XCTAssertEqual(briefingContinue.label, "Get Started")
        let briefingActionFrame = briefingContinue.frame
        XCTAssertGreaterThanOrEqual(briefingActionFrame.height, 44)
        XCTAssertLessThanOrEqual(
            briefingActionFrame.height,
            60,
            "The full-width native action should not add custom vertical height."
        )
        XCTAssertGreaterThan(briefingActionFrame.width, app.frame.width * 0.8)

        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            briefingContinue,
            destination: name,
            in: app
        ) else { return }
        let businessContinue = app.buttons["business-profile-save-action"]
        XCTAssertEqual(
            businessContinue.frame.width,
            briefingActionFrame.width,
            accuracy: 1
        )
        XCTAssertEqual(
            businessContinue.frame.height,
            briefingActionFrame.height,
            accuracy: 1
        )
        focusAndType("Compact Action Farrier", in: name, app: app)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertFalse(
            app.buttons["Done"].waitForExistence(timeout: 2),
            "The single onboarding field should not add a redundant keyboard toolbar."
        )

        let subscriptionContinue = app.buttons["subscription-primary-purchase"]
        guard tapUntilDestinationAppears(
            businessContinue,
            destination: subscriptionContinue,
            in: app
        ) else { return }

        XCTAssertEqual(
            subscriptionContinue.frame.width,
            briefingActionFrame.width,
            accuracy: 1
        )
        XCTAssertEqual(
            subscriptionContinue.frame.height,
            briefingActionFrame.height,
            accuracy: 1
        )
    }

    @MainActor
    func testOnboardingDarkModeUsesTheBrandBackground() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupDarkBrandSurface-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = "dark"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding-welcome"]
                .waitForExistence(timeout: 5)
        )
        let screenshot = app.screenshot().image
        guard let color = averageRGB(
            in: screenshot,
            around: CGPoint(x: 8, y: app.frame.midY)
        ) else {
            XCTFail("Could not sample the onboarding background.")
            return
        }

        XCTAssertEqual(color.red, 23.0 / 255, accuracy: 0.02)
        XCTAssertEqual(color.green, 21.0 / 255, accuracy: 0.02)
        XCTAssertEqual(color.blue, 19.0 / 255, accuracy: 0.02)
    }

    @MainActor
    func testBusinessIdentityGroupCentersBelowTheHero() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupCenteredBusiness-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        let briefingContinue = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(briefingContinue))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            briefingContinue,
            destination: name,
            in: app
        ) else { return }

        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }

        let heroCandidates = app.staticTexts.matching(identifier: "Your Business")
        let hero = (0..<heroCandidates.count)
            .map { heroCandidates.element(boundBy: $0) }
            .max { $0.frame.width < $1.frame.width } ?? heroCandidates.firstMatch
        let sectionTitle = app.staticTexts["Make it yours."]
        let sectionLastLine = app.staticTexts[
            "Appears on invoices. You can change it later."
        ]
        let continueAction = app.buttons["business-profile-save-action"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(sectionTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(sectionLastLine.waitForExistence(timeout: 3))
        XCTAssertTrue(continueAction.waitForExistence(timeout: 3))

        let contentTop = app.navigationBars["Your Business"].frame.maxY
        let availableCenterY = (contentTop + continueAction.frame.minY) / 2
        XCTAssertLessThanOrEqual(
            sectionTitle.frame.minY - hero.frame.maxY,
            112,
            "The title and identity form should read as one intentional composition."
        )
        XCTAssertEqual(
            (hero.frame.minY + sectionLastLine.frame.maxY) / 2,
            availableCenterY,
            accuracy: 48,
            "The complete business composition should sit in the center of the usable space."
        )
    }

    @MainActor
    func testOnboardingBillingSelectorIsCompactAtStandardTextSize() {
        checkBillingSelectionHierarchy(appearance: "light")
    }

    @MainActor
    func testOnboardingBillingSelectionKeepsPurchaseDominantInDarkMode() {
        checkBillingSelectionHierarchy(appearance: "dark")
    }

    @MainActor
    private func checkBillingSelectionHierarchy(appearance: String) {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupCompactBillingSelector-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_COLOR_SCHEME"] = appearance
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"] =
            "read-only"
        app.launch()
        defer { app.terminate() }

        let briefingContinue = app.buttons["onboarding-briefing-continue"]
        XCTAssertTrue(waitUntilEnabled(briefingContinue))
        let name = app.textFields["business-profile-name-field"]
        guard tapUntilDestinationAppears(
            briefingContinue,
            destination: name,
            in: app
        ) else { return }
        focusAndType("Compact Billing Farrier", in: name, app: app)
        guard tapUntilDestinationAppears(
            app.buttons["business-profile-save-action"],
            destination: app.navigationBars["FarrierFlow Pro"],
            in: app
        ) else { return }

        let monthly = app.buttons["subscription-plan-monthly"]
        let yearly = app.buttons["subscription-plan-annual"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        XCTAssertTrue(yearly.exists)
        let selectorWidth = max(monthly.frame.maxX, yearly.frame.maxX)
            - min(monthly.frame.minX, yearly.frame.minX)
        XCTAssertLessThanOrEqual(
            selectorWidth,
            app.frame.width * 0.84,
            "The billing choice should be a compact selector, not a full-width panel."
        )
        XCTAssertEqual(monthly.frame.height, 44, accuracy: 0.5)
        XCTAssertEqual(yearly.frame.height, 44, accuracy: 0.5)

        let purchase = app.buttons["subscription-primary-purchase"]
        XCTAssertTrue(purchase.isHittable)
        XCTAssertEqual(purchase.label, "Start 2-Week Free Trial")
        for selected in [yearly, monthly] {
            if !selected.isSelected {
                selected.tap()
            }
            XCTAssertTrue(selected.isSelected)
            let screenshot = app.screenshot().image
            // Sample empty fill above the label, away from the capsule edge.
            let selectionColor = averageRGB(
                in: screenshot,
                around: CGPoint(x: selected.frame.midX, y: selected.frame.minY + 5)
            )
            let actionColor = averageRGB(
                in: screenshot,
                around: CGPoint(x: purchase.frame.minX + 30, y: purchase.frame.midY)
            )
            guard let selectionColor, let actionColor else {
                XCTFail("Could not sample the selected plan and purchase fills.")
                return
            }
            let tint: (CGFloat, CGFloat, CGFloat) = appearance == "dark"
                ? (59, 37, 22) : (255, 241, 230)
            let brand: (CGFloat, CGFloat, CGFloat) = appearance == "dark"
                ? (224, 108, 18) : (191, 87, 0)
            XCTAssertEqual(selectionColor.red, tint.0 / 255, accuracy: 0.03)
            XCTAssertEqual(selectionColor.green, tint.1 / 255, accuracy: 0.03)
            XCTAssertEqual(selectionColor.blue, tint.2 / 255, accuracy: 0.03)
            XCTAssertEqual(actionColor.red, brand.0 / 255, accuracy: 0.03)
            XCTAssertEqual(actionColor.green, brand.1 / 255, accuracy: 0.03)
            XCTAssertEqual(actionColor.blue, brand.2 / 255, accuracy: 0.03)
            keepScreenshot(named: "Paywall-\(appearance)-\(selected.identifier)", of: app)
        }
    }

    @MainActor
    func testFreshOnboardingLaunchDoesNotRequestSystemPermissions() {
        let app = XCUIApplication()
        app.launchEnvironment["FARRIERFLOW_UI_TEST_STORE"] =
            "OwnerSetupNoPermissionPrompt-\(UUID().uuidString)"
        app.launchEnvironment["FARRIERFLOW_UI_TEST_SCENARIO"] = "owner-setup"
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding-welcome"]
                .waitForExistence(timeout: 5)
        )

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permissionCopy = springboard.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@",
                "FarrierFlow",
                "would like"
            )
        )
        XCTAssertFalse(
            permissionCopy.firstMatch.waitForExistence(timeout: 1),
            "FarrierFlow should request permissions only after a relevant user action."
        )
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
        let clientNameField = app.textFields["client-name-field"]
        guard tapUntilDestinationAppears(
            addFirstClient,
            destination: clientNameField,
            in: app
        ) else { return }
        focusAndType(clientName, in: clientNameField, app: app)
        app.buttons["Save"].tap()

        let schedule = app.buttons["Schedule Appointment"].firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 3))
        schedule.tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
        let addLocation = app.buttons["appointment-add-service-location"]
        XCTAssertTrue(addLocation.waitForExistence(timeout: 3))
        tapAfterBringingIntoView(addLocation, in: app)
        XCTAssertTrue(
            app.navigationBars["New Service Location"].waitForExistence(timeout: 3)
        )
        focusAndType(locationName, in: app.textFields["barn-name-field"], app: app)
        let arrivalDetails = app.buttons["barn-more-details"]
        XCTAssertTrue(arrivalDetails.waitForExistence(timeout: 3))
        tapAfterBringingIntoView(arrivalDetails, in: app)
        focusAndType(
            locationAddress,
            in: field(withPlaceholder: "Address", in: app),
            app: app
        )
        focusAndType(arrivalNotes, in: app.textViews["Contact Notes"], app: app)
        app.navigationBars["New Service Location"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
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

        XCTAssertTrue(app.navigationBars["New Appointment"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityText(of: app.buttons["appointment-barn-picker"])
                .contains(locationName)
        )
        app.navigationBars["New Appointment"].buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let scheduledStop = app.buttons["today-run-sheet-scheduled"]
        XCTAssertTrue(scheduledStop.waitForExistence(timeout: 5))
        XCTAssertTrue(accessibilityText(of: scheduledStop).contains(locationAddress))
        let detailAddress = app.descendants(matching: .any)[
            "appointment-detail-address"
        ]
        guard tapUntilDestinationAppears(
            scheduledStop,
            destination: detailAddress,
            in: app
        ) else { return }
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
        let createInvoice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Create Invoice")
        ).firstMatch
        XCTAssertTrue(createInvoice.waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(createInvoice.waitForExistence(timeout: 3))
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
        if waitForKeyboardFocus(in: element) {
            element.typeText(text)
            return
        }
        guard bringIntoView(element, in: app), element.isHittable else {
            XCTFail("Expected text field to become visible and hittable")
            return
        }
        for _ in 0..<3 {
            element.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            ).tap()
            if waitForKeyboardFocus(in: element) {
                element.typeText(text)
                return
            }
        }
        XCTFail("Text field did not receive keyboard focus")
    }

    @MainActor
    private func waitForKeyboardFocus(in element: XCUIElement) -> Bool {
        let focusExpectation = expectation(
            for: NSPredicate(format: "hasKeyboardFocus == true"),
            evaluatedWith: element
        )
        return XCTWaiter().wait(for: [focusExpectation], timeout: 2) == .completed
    }

    @MainActor
    private func field(
        withPlaceholder placeholder: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "placeholderValue == %@", placeholder))
            .firstMatch
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
    private func tapUntilDestinationAppears(
        _ action: XCUIElement,
        destination: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<2 {
            guard action.waitForExistence(timeout: 3) else { continue }
            tapAfterBringingIntoView(action, in: app)
            if destination.waitForExistence(timeout: 3) {
                return true
            }
        }
        XCTFail("Expected action to open its destination")
        return false
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        let enabled = expectation(
            for: NSPredicate(format: "isEnabled == true"),
            evaluatedWith: element
        )
        return XCTWaiter().wait(for: [enabled], timeout: 3) == .completed
    }

    @MainActor
    private func bringIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<8 {
            let visibleFrame = unobscuredFrame(in: app, excluding: element)
            if element.exists,
               element.isHittable,
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
        let visibleFrame = unobscuredFrame(in: app, excluding: element)
        return element.exists
            && element.isHittable
            && visibleFrame.contains(
                CGPoint(x: element.frame.midX, y: element.frame.midY)
            )
    }

    @MainActor
    private func unobscuredFrame(
        in app: XCUIApplication,
        excluding element: XCUIElement
    ) -> CGRect {
        let appFrame = app.frame
        let bottomActions = [
            app.buttons["business-profile-save-action"],
            app.buttons["subscription-primary-purchase"]
        ]
        let bottomActionIdentifiers: Set<String> = [
            "business-profile-save-action",
            "subscription-primary-purchase"
        ]
        let targetIsBottomAction = bottomActionIdentifiers.contains(
            element.identifier
        )
        let keyboard = app.keyboards.firstMatch
        var bottom = targetIsBottomAction || !keyboard.exists
            ? appFrame.maxY
            : keyboard.frame.minY
        if !targetIsBottomAction {
            for action in bottomActions where action.exists {
                bottom = min(bottom, action.frame.minY)
            }
        }
        return CGRect(
            x: appFrame.minX,
            y: appFrame.minY + 100,
            width: appFrame.width,
            height: max(0, bottom - appFrame.minY - 120)
        )
    }

    @MainActor
    private func scrollForm(in app: XCUIApplication, upward: Bool) {
        let collectionViews = app.collectionViews
        guard collectionViews.count > 0 else {
            let firstScrollView = app.scrollViews.firstMatch
            let scrollSurface = firstScrollView.exists ? firstScrollView : app
            let startY = upward ? 0.72 : 0.36
            let endY = upward ? 0.38 : 0.70
            scrollSurface.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: startY)
            ).press(
                forDuration: 0.05,
                thenDragTo: scrollSurface.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: endY)
                )
            )
            return
        }

        let form = collectionViews.element(
            boundBy: min(1, collectionViews.count - 1)
        )
        if upward {
            form.swipeUp()
        } else {
            form.swipeDown()
        }
    }

    @MainActor
    private func keepScreenshot(
        named name: String,
        of app: XCUIApplication
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func averageRGB(
        in image: UIImage,
        around point: CGPoint
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let inputImage = CIImage(image: image),
              let filter = CIFilter(name: "CIAreaAverage") else {
            return nil
        }
        let scale = image.scale
        let sampleSize = max(2, scale * 2)
        let sampleRect = CGRect(
            x: point.x * scale,
            y: inputImage.extent.height - (point.y * scale) - sampleSize,
            width: sampleSize,
            height: sampleSize
        ).intersection(inputImage.extent)
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: sampleRect), forKey: kCIInputExtentKey)
        guard let outputImage = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (
            CGFloat(pixel[0]) / 255,
            CGFloat(pixel[1]) / 255,
            CGFloat(pixel[2]) / 255
        )
    }

    @MainActor
    private func accessibilityText(of element: XCUIElement) -> String {
        [element.label, element.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
