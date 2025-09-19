import Foundation
import SwiftUI

// MARK: - Recommendation Models

struct NutritionRecommendation: Identifiable, Codable {
    enum RecommendationType: String, Codable {
        case deficiencyCorrection
        case swapSuggestion
        case habitPattern
        case riskAlert
        case categoryExploration
        case synergyPairing
        case hydration
        case correlationInsight
    }

    var id: UUID = UUID()
    var title: String
    var message: String
    var reason: String
    var relevanceScore: Double
    var type: RecommendationType
    var tags: [String] = []
    var evidence: [String] = []
}

struct NutrientDeficiency: Codable {
    enum Nutrient: String, Codable, CaseIterable {
        case fiber
        case protein
        case vitaminC
        case iron
        case calcium
        case potassium
        case magnesium
        case omega3
    }

    let nutrient: Nutrient
    let deficitMagnitude: Double   // relative deficit 0..1
    let evidenceCount: Int
    // Explainability fields
    let avgValue: Double
    let targetValue: Double
    let windowDays: Int
    let samplePlates: [SampleRef]
    let sampleProducts: [SampleRef]
}

struct SampleRef: Codable, Identifiable {
    enum Kind: String, Codable { case plate, product }
    var id: String { key }
    let kind: Kind
    let key: String   // plate UUID or product barcode
    let name: String
    let dateISO: String
    let metricLabel: String // e.g., "fiber", "protein", "sugar", "sodium"
    let metricValue: String // e.g., "8 g", "1.6 g"
}

struct CorrelationInsight: Identifiable, Codable {
    enum CorrelationType: String, Codable {
        case sugarVsPlateScore
        case sodiumVsPlateScore
        case categoryHabit
        case timeOfDayHabit
        case micronutrientGap
    }

    var id: UUID = UUID()
    let type: CorrelationType
    let description: String
    let score: Double  // strength 0..1
    let tags: [String]
    let evidence: [String]
}
