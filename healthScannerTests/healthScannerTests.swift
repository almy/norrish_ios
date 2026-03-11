//
//  healthScannerTests.swift
//  healthScannerTests
//
//  Created by myftiu on 06/09/25.
//

import XCTest
@testable import healthScanner

final class healthScannerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testIngredientFlagsMatchDairyMilkPowder() {
        let preferences = DietaryPreferencesManager.shared
        let originalAllergies = preferences.selectedAllergies
        let originalRestrictions = preferences.selectedDietaryRestrictions
        let originalCustomAllergies = preferences.customAllergies
        let originalCustomRestrictions = preferences.customRestrictions

        preferences.selectedAllergies = [.dairy]
        preferences.selectedDietaryRestrictions = []
        preferences.customAllergies = []
        preferences.customRestrictions = []

        defer {
            preferences.selectedAllergies = originalAllergies
            preferences.selectedDietaryRestrictions = originalRestrictions
            preferences.customAllergies = originalCustomAllergies
            preferences.customRestrictions = originalCustomRestrictions
        }

        let flags = preferences.ingredientFlags(for: "Milk Powder")

        XCTAssertEqual(flags.count, 1)
        XCTAssertTrue(flags.allSatisfy(\.isAllergy))
        XCTAssertEqual(flags.first?.matchedKeyword, "milk")
    }

    func testIngredientFlagsMatchCustomRestriction() {
        let preferences = DietaryPreferencesManager.shared
        let originalAllergies = preferences.selectedAllergies
        let originalRestrictions = preferences.selectedDietaryRestrictions
        let originalCustomAllergies = preferences.customAllergies
        let originalCustomRestrictions = preferences.customRestrictions

        preferences.selectedAllergies = []
        preferences.selectedDietaryRestrictions = []
        preferences.customAllergies = []
        preferences.customRestrictions = ["chia"]

        defer {
            preferences.selectedAllergies = originalAllergies
            preferences.selectedDietaryRestrictions = originalRestrictions
            preferences.customAllergies = originalCustomAllergies
            preferences.customRestrictions = originalCustomRestrictions
        }

        let flags = preferences.ingredientFlags(for: "Black chia seeds")

        XCTAssertEqual(flags.count, 1)
        XCTAssertFalse(flags.contains(where: \.isAllergy))
        XCTAssertEqual(flags.first?.matchedKeyword, "chia")
    }

}
