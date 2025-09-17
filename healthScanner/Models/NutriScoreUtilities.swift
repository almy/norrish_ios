//
//  NutriScoreUtilities.swift
//  healthScanner
//
//  Shared utilities for Nutri-Score calculation and breakdown
//

import Foundation

// MARK: - Nutri-Score Types

enum NutriScoreLetter: String, CaseIterable {
    case A = "A"
    case B = "B"
    case C = "C"
    case D = "D"
    case E = "E"

    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .A: return (red: 0.0, green: 0.5, blue: 0.0)
        case .B: return (red: 0.5, green: 0.8, blue: 0.0)
        case .C: return (red: 1.0, green: 0.8, blue: 0.0)
        case .D: return (red: 1.0, green: 0.5, blue: 0.0)
        case .E: return (red: 0.8, green: 0.0, blue: 0.0)
        }
    }
}

struct NutriScoreBreakdown {
    let letter: NutriScoreLetter
    let finalScore: Int
    let category: String
    let negatives: [(name: String, points: Int)]
    let positives: [(name: String, points: Int)]
}

// MARK: - Nutri-Score Calculation Functions

func computeNutriScoreBreakdown(_ data: NutritionData, categories: [String]? = nil) -> NutriScoreBreakdown {
    let cats = Set((categories ?? []).map { $0.lowercased() })
    let isWater = cats.contains("en:waters") || cats.contains("en:water")
    let isBeverage = isWater || cats.contains("en:beverages") || cats.contains("en:non-alcoholic-beverages") || cats.contains("en:sodas")
    let isCheese = cats.contains("en:cheeses") || cats.contains("en:cheese")
    let isOliveOil = cats.contains("en:olive-oils") || cats.contains("en:olive-oil")
    let isRapeseedOil = cats.contains("en:rapeseed-oil") || cats.contains("en:rapeseed-oils")
    let isWalnutOil = cats.contains("en:walnut-oil") || cats.contains("en:walnut-oils")
    let isSpecialOil = isOliveOil || isRapeseedOil || isWalnutOil
    let category = isWater ? "Water" : (isBeverage ? "Beverage" : (isCheese ? "Cheese" : (isSpecialOil ? "Special oil" : "General food")))

    if isWater {
        return NutriScoreBreakdown(letter: .A, finalScore: 0, category: category, negatives: [], positives: [])
    }

    var negatives: [(name: String, points: Int)] = []
    var positives: [(name: String, points: Int)] = []

    // Negative points
    let energyPoints = energyPoints(calories: data.calories, isBeverage: isBeverage)
    let sugarPoints = sugarPoints(sugar: data.sugar, isBeverage: isBeverage)
    let saturatedFatPoints = saturatedFatPoints(saturatedFat: data.saturatedFat, isBeverage: isBeverage)
    let sodiumPoints = sodiumPoints(sodium: data.sodium, isBeverage: isBeverage)

    if energyPoints > 0 { negatives.append((name: "Energy", points: energyPoints)) }
    if sugarPoints > 0 { negatives.append((name: "Sugar", points: sugarPoints)) }
    if saturatedFatPoints > 0 { negatives.append((name: "Saturated fat", points: saturatedFatPoints)) }
    if sodiumPoints > 0 { negatives.append((name: "Sodium", points: sodiumPoints)) }

    let totalNegative = energyPoints + sugarPoints + saturatedFatPoints + sodiumPoints

    // Positive points
    let fruitsVegPoints = fruitsVegetablesPoints(percent: data.fruitsVegetablesNutsPercent ?? 0)
    let fiberPoints = fiberPoints(fiber: data.fiber, isBeverage: isBeverage)
    let proteinPoints = proteinPoints(protein: data.protein, totalNegative: totalNegative, isCheese: isCheese, isBeverage: isBeverage)

    if fruitsVegPoints > 0 { positives.append((name: "Fruits/vegetables/nuts", points: fruitsVegPoints)) }
    if fiberPoints > 0 { positives.append((name: "Fiber", points: fiberPoints)) }
    if proteinPoints > 0 { positives.append((name: "Protein", points: proteinPoints)) }

    let totalPositive = fruitsVegPoints + fiberPoints + proteinPoints
    let finalScore = totalNegative - totalPositive

    let letter: NutriScoreLetter
    if isBeverage {
        letter = beverageNutriScoreLetter(finalScore)
    } else {
        letter = generalNutriScoreLetter(finalScore)
    }

    return NutriScoreBreakdown(letter: letter, finalScore: finalScore, category: category, negatives: negatives, positives: positives)
}

func nutriScoreForProduct(_ data: NutritionData, categories: [String]? = nil) -> NutriScoreLetter {
    return computeNutriScoreBreakdown(data, categories: categories).letter
}

func nutriScoreForProduct(_ product: Product) -> NutriScoreLetter {
    return nutriScoreForProduct(product.nutritionData, categories: product.categoriesTags)
}

func nutriScoreForPlate(score0to10: Double) -> NutriScoreLetter {
    // Map 0–10 nutritionScore to Nutri-Score buckets
    switch score0to10 {
    case 8.0...: return .A
    case 6.5..<8.0: return .B
    case 5.0..<6.5: return .C
    case 3.5..<5.0: return .D
    default: return .E
    }
}

// MARK: - Private Helper Functions

private func energyPoints(calories: Double, isBeverage: Bool) -> Int {
    let thresholds: [Double] = isBeverage ? [0, 30, 60, 90, 120, 150, 180, 210, 240, 270] : [335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350]
    return pointsFromThresholds(value: calories, thresholds: thresholds)
}

private func sugarPoints(sugar: Double, isBeverage: Bool) -> Int {
    let thresholds: [Double] = isBeverage ? [0, 1.5, 3, 4.5, 6, 7.5, 9, 10.5, 12, 13.5] : [4.5, 9, 13.5, 18, 22.5, 27, 31, 36, 40, 45]
    return pointsFromThresholds(value: sugar, thresholds: thresholds)
}

private func saturatedFatPoints(saturatedFat: Double, isBeverage: Bool) -> Int {
    if isBeverage { return 0 }
    let thresholds: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    return pointsFromThresholds(value: saturatedFat, thresholds: thresholds)
}

private func sodiumPoints(sodium: Double, isBeverage: Bool) -> Int {
    let thresholds: [Double] = isBeverage ? [0, 0.045, 0.09, 0.135, 0.18, 0.225, 0.27, 0.315, 0.36, 0.405] : [0.09, 0.18, 0.27, 0.36, 0.45, 0.54, 0.63, 0.72, 0.81, 0.9]
    return pointsFromThresholds(value: sodium, thresholds: thresholds)
}

private func fruitsVegetablesPoints(percent: Double) -> Int {
    switch percent {
    case 80...: return 5
    case 60..<80: return 2
    case 40..<60: return 1
    default: return 0
    }
}

private func fiberPoints(fiber: Double, isBeverage: Bool) -> Int {
    if isBeverage { return 0 }
    let thresholds: [Double] = [0.9, 1.9, 2.8, 3.7, 4.7]
    return min(pointsFromThresholds(value: fiber, thresholds: thresholds), 5)
}

private func proteinPoints(protein: Double, totalNegative: Int, isCheese: Bool, isBeverage: Bool) -> Int {
    if isBeverage { return 0 }
    if isCheese || totalNegative < 11 {
        let thresholds: [Double] = [1.6, 3.2, 4.8, 6.4, 8.0]
        return min(pointsFromThresholds(value: protein, thresholds: thresholds), 5)
    }
    return 0
}

private func pointsFromThresholds(value: Double, thresholds: [Double]) -> Int {
    for (index, threshold) in thresholds.enumerated() {
        if value <= threshold {
            return index
        }
    }
    return thresholds.count
}

private func generalNutriScoreLetter(_ finalScore: Int) -> NutriScoreLetter {
    switch finalScore {
    case ...(-1): return .A
    case 0...2: return .B
    case 3...10: return .C
    case 11...18: return .D
    default: return .E
    }
}

private func beverageNutriScoreLetter(_ finalScore: Int) -> NutriScoreLetter {
    switch finalScore {
    case ...1: return .B
    case 2...5: return .C
    case 6...9: return .D
    default: return .E
    }
}