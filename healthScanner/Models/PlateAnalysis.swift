//
//  PlateAnalysis.swift
//  healthScanner
//
//  Core data models for plate analysis functionality
//

import Foundation

// MARK: - Main PlateAnalysis Model
struct PlateAnalysis: Codable, Equatable {
    let nutritionScore: Double
    let description: String
    let macronutrients: Macronutrients
    let ingredients: [Ingredient]
    let insights: [Insight]
    let micronutrients: Micronutrients?
    let connections: [String]?

    static func mockAnalysis() -> PlateAnalysis {
        return PlateAnalysis(
            nutritionScore: 8.5,
            description: "Healthy Quinoa Bowl",
            macronutrients: Macronutrients(
                protein: 25,
                carbs: 40,
                fat: 15,
                calories: 450
            ),
            ingredients: [
                Ingredient(name: "Quinoa", amount: "100g"),
                Ingredient(name: "Broccoli", amount: "150g"),
                Ingredient(name: "Olive Oil", amount: "15ml")
            ],
            insights: [
                Insight(type: .positive, title: "Excellent Protein Source", description: "This meal provides complete proteins from quinoa."),
                Insight(type: .suggestion, title: "Add More Color", description: "Consider adding red bell peppers for extra vitamins.")
            ],
            micronutrients: Micronutrients(
                fiberG: 8,
                vitaminCMg: 85,
                ironMg: 4,
                other: "Rich in vitamin K, folate, and magnesium"
            ),
            connections: [
                "High fiber content supports digestive health",
                "Complete amino acid profile from quinoa"
            ]
        )
    }
}

// MARK: - Supporting Models
struct Macronutrients: Codable, Equatable {
    let protein: Int
    let carbs: Int
    let fat: Int
    let calories: Int
}

struct Micronutrients: Codable, Equatable {
    let fiberG: Int?
    let vitaminCMg: Int?
    let ironMg: Int?
    let other: String?
}

struct Ingredient: Codable, Equatable {
    let name: String
    let amount: String
}

struct Insight: Codable, Equatable {
    let type: InsightType
    let title: String
    let description: String

    enum InsightType: String, Codable, Equatable {
        case positive
        case suggestion
        case warning
    }
}
