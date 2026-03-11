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

        addUIInterruptionMonitor(withDescription: "System Permission Alerts") { alert in
            let allowButtons = [
                "Allow",
                "Allow While Using App",
                "OK",
                "Continue",
                "Don’t Allow",
                "Don't Allow",
                "Not Now"
            ]

            for label in allowButtons {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }

            if alert.buttons.firstMatch.exists {
                alert.buttons.firstMatch.tap()
                return true
            }

            return false
        }
    }

    @discardableResult
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NORRISH_SCREENSHOT_MODE"] = "1"
        app.launchEnvironment["NORRISH_INITIAL_TAB"] = "home"
        app.launchEnvironment["API_BASE_URL"] = "https://example.com"
        app.launchEnvironment["API_KEY"] = "ui-test-key"
        app.launch()
        app.tap() // Triggers interruption monitor if any startup system alert is shown.
        return app
    }

    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    private func waitForHomeReady(_ app: XCUIApplication, timeout: TimeInterval = 12) {
        XCTAssertTrue(app.otherElements["root.tabView"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.otherElements["screen.home"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["fab.quickAdd"].waitForExistence(timeout: timeout))
    }

    private func firstExistingButton(in tabBar: XCUIElement, labels: [String]) -> XCUIElement? {
        for label in labels {
            let button = tabBar.buttons[label]
            if button.exists {
                return button
            }
        }
        return nil
    }

    private func existsAnyElement(in app: XCUIApplication, labels: [String]) -> Bool {
        for label in labels {
            if app.descendants(matching: .any)[label].exists {
                return true
            }
        }
        return false
    }

    func testLaunchesToHomeScreen() throws {
        let app = launchApp()

        XCTAssertTrue(app.otherElements["root.tabView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["screen.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["fab.quickAdd"].waitForExistence(timeout: 5))
    }

    func testQuickAddSheetShowsAllActions() throws {
        let app = launchApp()
        waitForHomeReady(app)

        tapWhenHittable(app.buttons["fab.quickAdd"])

        let quickAddSheet = app.descendants(matching: .any)["sheet.quickAdd"]
        XCTAssertTrue(quickAddSheet.waitForExistence(timeout: 10))
        XCTAssertTrue(existsAnyElement(in: app, labels: ["Scan Product", "Scan", "tab.scan"]))
        XCTAssertTrue(existsAnyElement(in: app, labels: ["Analyze Plate", "Plate", "tab.plate"]))
        XCTAssertTrue(existsAnyElement(in: app, labels: ["Upload Photo", "plate.upload_photo"]))
    }

    func testCanNavigateToHistoryAndProfileTabs() throws {
        let app = launchApp()
        waitForHomeReady(app)
        let tabBar = app.tabBars.firstMatch

        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(tabBar.buttons.count, 3)

        if let historyButton = firstExistingButton(
            in: tabBar,
            labels: ["History", "Historik", "tab.history", "Clock"]
        ) {
            tapWhenHittable(historyButton)
        } else {
            tabBar.buttons.element(boundBy: 1).tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["screen.history"].waitForExistence(timeout: 12))

        if let profileButton = firstExistingButton(
            in: tabBar,
            labels: ["Profile", "Profil", "tab.profile", "Person"]
        ) {
            tapWhenHittable(profileButton)
        } else {
            tabBar.buttons.element(boundBy: 2).tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["screen.profile"].waitForExistence(timeout: 12))
    }

    func testPlateAnalysisResultShowsCondensedAIDisclaimer() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NORRISH_SCREENSHOT_MODE"] = "1"
        app.launchEnvironment["NORRISH_SCREENSHOT_ROUTE"] = "plate_analysis_result"
        app.launchEnvironment["API_BASE_URL"] = "https://example.com"
        app.launchEnvironment["API_KEY"] = "ui-test-key"
        app.launch()

        let disclaimer = app.staticTexts["plateAnalysis.aiEstimateDisclaimer"]
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 10))
        XCTAssertEqual(disclaimer.label, "AI estimate — tap for detail.")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Plate Analysis Result Disclaimer"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
