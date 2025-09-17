//
//  String+Localization.swift
//  healthScanner
//
//  Extensions for easier localization
//

import Foundation

extension String {
    /// Localized string using the current locale and LocalizationManager
    var localized: String {
        return LocalizationManager.shared.localizedString(forKey: self, comment: "")
    }

    /// Localized string with comment for better context
    func localized(comment: String = "") -> String {
        return LocalizationManager.shared.localizedString(forKey: self, comment: comment)
    }

    /// Localized string with format arguments
    func localizedFormat(_ arguments: CVarArg...) -> String {
        let localizedString = LocalizationManager.shared.localizedString(forKey: self, comment: "")
        return String(format: localizedString, arguments)
    }
}

// MARK: - Localization Keys
extension String {
    // Tab titles
    static let tabScan = "tab.scan"
    static let tabPlate = "tab.plate"
    static let tabHistory = "tab.history"
    static let tabProfile = "tab.profile"

    // Filters
    static let filterAll = "filter.all"
    static let filterGradeA = "filter.grade_a"
    static let filterGradeB = "filter.grade_b"
    static let filterGradeC = "filter.grade_c"
    static let filterGradeD = "filter.grade_d"
    static let filterGradeE = "filter.grade_e"

    // Nutrition
    static let nutritionCalories = "nutrition.calories"
    static let nutritionFat = "nutrition.fat"
    static let nutritionCarbs = "nutrition.carbs"
    static let nutritionProtein = "nutrition.protein"
    static let nutritionFiber = "nutrition.fiber"
    static let nutritionSugar = "nutrition.sugar"

    // Units
    static let unitGrams = "unit.grams"
    static let unitMilligrams = "unit.milligrams"
    static let unitKilocalories = "unit.kilocalories"
}