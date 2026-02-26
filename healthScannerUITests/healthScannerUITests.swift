//
//  healthScannerUITests.swift
//  healthScannerUITests
//
//  Created by myftiu on 06/09/25.
//

import XCTest

final class healthScannerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NORRISH_SCREENSHOT_MODE"] = "1"
        app.launchEnvironment["API_BASE_URL"] = "https://example.com"
        app.launchEnvironment["API_KEY"] = "ui-test-key"
        app.launch()
        return app
    }

    func testLaunchesToHomeScreen() throws {
        let app = launchApp()

        XCTAssertTrue(app.otherElements["root.tabView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["screen.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["fab.quickAdd"].waitForExistence(timeout: 5))
    }

    func testQuickAddSheetShowsAllActions() throws {
        let app = launchApp()

        app.buttons["fab.quickAdd"].tap()

        XCTAssertTrue(app.otherElements["sheet.quickAdd"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quickAdd.scanBarcode"].exists)
        XCTAssertTrue(app.buttons["quickAdd.scanPlate"].exists)
        XCTAssertTrue(app.buttons["quickAdd.uploadPhoto"].exists)
    }

    func testCanNavigateToHistoryAndProfileTabs() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch

        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(tabBar.buttons.count, 3)

        tabBar.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.otherElements["screen.history"].waitForExistence(timeout: 5))

        tabBar.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.otherElements["screen.profile"].waitForExistence(timeout: 5))
    }
}
