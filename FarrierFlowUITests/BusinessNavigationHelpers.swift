import XCTest

extension XCUIApplication {
    @MainActor
    func selectFarrierFlowTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<2 {
            if tab.isSelected { return }
            tab.press(forDuration: 0.1)
            let selected = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "selected == true"), object: tab
            )
            if XCTWaiter.wait(for: [selected], timeout: 2) == .completed { return }
        }
        XCTAssertTrue(tab.isSelected, debugDescription, file: file, line: line)
    }

    @MainActor
    func openBusinessRoot(file: StaticString = #filePath, line: UInt = #line) {
        // Focused editors and account screens deliberately hide the tab bar.
        // Return through their native back navigation before selecting a tab.
        for _ in 0..<8 where !tabBars.firstMatch.exists {
            let back = navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 3) else { break }
            back.tap()
        }
        selectFarrierFlowTab("Business", file: file, line: line)
        for _ in 0..<8 {
            if navigationBars["Business"].exists { return }
            let back = navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 3) else { break }
            back.tap()
        }
        XCTAssertTrue(navigationBars["Business"].waitForExistence(timeout: 3), file: file, line: line)
    }
}
