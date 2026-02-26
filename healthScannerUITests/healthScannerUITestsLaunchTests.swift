//
//  healthScannerUITestsLaunchTests.swift
//  healthScannerUITests
//
//  Created by myftiu on 06/09/25.
//

import XCTest

final class healthScannerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NORRISH_SCREENSHOT_MODE"] = "1"
        app.launchEnvironment["API_BASE_URL"] = "https://example.com"
        app.launchEnvironment["API_KEY"] = "ui-test-key"
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
