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
    let mealType: String?
    let portionEstimate: PortionEstimate?
    let confidenceIdentification: Double?
    let confidenceQuantity: Double?
    let confidenceOverall: Double?
    let uncertaintyNotes: [String]?
    let topAssumptions: [String]?
    let whyThisScore: [String]?
    let quickWinActions: [String]?

    init(
        nutritionScore: Double,
        description: String,
        macronutrients: Macronutrients,
        ingredients: [Ingredient],
        insights: [Insight],
        micronutrients: Micronutrients?,
        connections: [String]?,
        mealType: String? = nil,
        portionEstimate: PortionEstimate? = nil,
        confidenceIdentification: Double? = nil,
        confidenceQuantity: Double? = nil,
        confidenceOverall: Double? = nil,
        uncertaintyNotes: [String]? = nil,
        topAssumptions: [String]? = nil,
        whyThisScore: [String]? = nil,
        quickWinActions: [String]? = nil
    ) {
        self.nutritionScore = nutritionScore
        self.description = description
        self.macronutrients = macronutrients
        self.ingredients = ingredients
        self.insights = insights
        self.micronutrients = micronutrients
        self.connections = connections
        self.mealType = mealType
        self.portionEstimate = portionEstimate
        self.confidenceIdentification = confidenceIdentification
        self.confidenceQuantity = confidenceQuantity
        self.confidenceOverall = confidenceOverall
        self.uncertaintyNotes = uncertaintyNotes
        self.topAssumptions = topAssumptions
        self.whyThisScore = whyThisScore
        self.quickWinActions = quickWinActions
    }

    var isGuardrailBlocked: Bool {
        if description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "analysis blocked" {
            return true
        }
        return insights.contains { insight in
            let title = insight.title.lowercased()
            let details = insight.description.lowercased()
            return title.contains("unsupported or unsafe image")
                || details.contains("not analyzed for safety reasons")
                || details.contains("analysis blocked")
        }
    }

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
            ],
            mealType: "lunch",
            portionEstimate: PortionEstimate(amount: 420, unit: "g", confidence: 0.72),
            confidenceIdentification: 0.88,
            confidenceQuantity: 0.66,
            confidenceOverall: 0.78,
            uncertaintyNotes: [],
            topAssumptions: [],
            whyThisScore: [],
            quickWinActions: []
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
    let notable: [MicronutrientNotable]?
    let summary: String?

    init(
        fiberG: Int?,
        vitaminCMg: Int?,
        ironMg: Int?,
        other: String?,
        notable: [MicronutrientNotable]? = nil,
        summary: String? = nil
    ) {
        self.fiberG = fiberG
        self.vitaminCMg = vitaminCMg
        self.ironMg = ironMg
        self.other = other
        self.notable = notable
        self.summary = summary
    }
}

struct MicronutrientNotable: Codable, Equatable {
    let name: String
    let amount: Double
    let unit: String
    let dailyValuePct: Int?
    let direction: String?
}

struct PortionEstimate: Codable, Equatable {
    let amount: Double
    let unit: String
    let confidence: Double
}

struct Ingredient: Codable, Equatable {
    let name: String
    let amount: String
    let confidence: Double?

    init(name: String, amount: String, confidence: Double? = nil) {
        self.name = name
        self.amount = amount
        self.confidence = confidence
    }
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
