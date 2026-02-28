//
//  NilsOnboardingTest.swift
//  healthScannerUITests
//
//  Norrish agent test: Navigate onboarding as Nils Eriksson persona
//  Saves screenshots to /tmp for easy retrieval
//

import XCTest

final class NilsOnboardingTest: XCTestCase {

    let outputDir = "/tmp/nils_onboarding_screens"

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Create output directory
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        addUIInterruptionMonitor(withDescription: "System Permission Alerts") { alert in
            let allowButtons = ["Allow", "Allow While Using App", "OK", "Continue", "Don't Allow", "Not Now"]
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

    func saveScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        if let pngData = screenshot.pngRepresentation {
            let path = "\(outputDir)/\(name).png"
            try? pngData.write(to: URL(fileURLWithPath: path))
        }
        // Also add as XCTest attachment
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNilsOnboardingFlow() throws {
        // Launch without screenshot mode to see onboarding
        let app = XCUIApplication()
        app.launchEnvironment["API_BASE_URL"] = "https://example.com"
        app.launchEnvironment["API_KEY"] = "ui-test-key"
        // Do NOT set NORRISH_SCREENSHOT_MODE so onboarding shows
        app.launch()

        // Wait for splash to finish (5 seconds minimum)
        Thread.sleep(forTimeInterval: 6.5)

        // Screenshot 1: Mission screen ("Nourishment through Insight")
        saveScreenshot(app, name: "nils_01_mission")

        // Tap "Begin Discovery" button
        let beginBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Discovery'")).firstMatch
        if beginBtn.waitForExistence(timeout: 5) {
            beginBtn.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 2: Trends screen ("Evolve with your Trends")
        saveScreenshot(app, name: "nils_02_trends")

        // Tap "Next" button
        let nextBtn1 = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Next'")).firstMatch
        if nextBtn1.waitForExistence(timeout: 5) {
            nextBtn1.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 3: Plate Scan screen ("Snap your Plate")
        saveScreenshot(app, name: "nils_03_plate_scan")

        // Tap "Next"
        let nextBtn2 = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Next'")).firstMatch
        if nextBtn2.waitForExistence(timeout: 5) {
            nextBtn2.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 4: Product Scan screen ("Scan any Product")
        saveScreenshot(app, name: "nils_04_product_scan")

        // Tap "Next"
        let nextBtn3 = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Next'")).firstMatch
        if nextBtn3.waitForExistence(timeout: 5) {
            nextBtn3.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 5: Profile screen ("Create Your Profile")
        saveScreenshot(app, name: "nils_05_profile")

        // Type a name
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("Nils")
        }
        Thread.sleep(forTimeInterval: 0.5)

        // Screenshot 6: Profile with name entered
        saveScreenshot(app, name: "nils_06_profile_filled")

        // Tap "Complete Profile"
        let completeBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Complete'")).firstMatch
        if completeBtn.waitForExistence(timeout: 5) {
            completeBtn.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)

        // Screenshot 7: Ready screen ("You're Ready")
        saveScreenshot(app, name: "nils_07_ready")
    }
}
