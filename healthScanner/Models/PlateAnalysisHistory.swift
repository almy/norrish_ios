//
//  PlateAnalysisHistory.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftData
import Foundation
import UIKit

enum MealLogIntent: String, Codable, CaseIterable, Identifiable {
    case ateIt = "ate_it"
    case boughtIt = "bought_it"
    case checkingInfo = "checking_info"
    case forSomeoneElse = "for_someone_else"

    var id: String { rawValue }
}

extension MealLogIntent {
    var title: String {
        switch self {
        case .ateIt:
            return "Eating / Ate it"
        case .boughtIt:
            return "Bought it"
        case .checkingInfo:
            return "Just checking info"
        case .forSomeoneElse:
            return "For someone else"
        }
    }

    var shortBadge: String {
        switch self {
        case .ateIt:
            return "Ate it"
        case .boughtIt:
            return "Bought it"
        case .checkingInfo:
            return "Checking info"
        case .forSomeoneElse:
            return "For someone else"
        }
    }
}

@Model
class PlateAnalysisHistory {
    var id: UUID
    var name: String
    var analyzedDate: Date
    var imageData: Data?
    var nutritionScore: Double
    var analysisDescription: String // Changed from 'description' to avoid conflict
    var protein: Int
    var carbs: Int
    var fat: Int
    var calories: Int
    var mealLogIntentRaw: String?
    var mealLoggedAt: Date?
    var ingredientsData: Data // JSON encoded ingredients
    var insightsData: Data // JSON encoded insights
    var microsData: Data? // JSON encoded Micronutrients
    var connectionsData: Data? // JSON encoded [String]
    @Relationship(deleteRule: .cascade, inverse: \PlateIngredientEntity.plate)
    var ingredientEntities: [PlateIngredientEntity] = []
    @Relationship(deleteRule: .cascade, inverse: \PlateInsightEntity.plate)
    var insightEntities: [PlateInsightEntity] = []
    @Transient private var cachedIngredientsData: Data?
    @Transient private var cachedIngredients: [PlateIngredient] = []
    @Transient private var cachedInsightsData: Data?
    @Transient private var cachedInsights: [PlateInsight] = []
    @Transient private var cachedMicrosData: Data?
    @Transient private var cachedMicronutrients: Micronutrients?
    @Transient private var cachedConnectionsData: Data?
    @Transient private var cachedConnections: [String] = []
    
    init(name: String, imageData: Data? = nil, nutritionScore: Double, description: String, protein: Int, carbs: Int, fat: Int, calories: Int, ingredients: [PlateIngredient], insights: [PlateInsight], micronutrients: Micronutrients? = nil, connections: [String]? = nil) {
        self.id = UUID()
        self.name = name
        self.analyzedDate = Date()
        self.imageData = imageData
        self.nutritionScore = nutritionScore
        self.analysisDescription = description // Updated to use new property name
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.calories = calories
        self.mealLogIntentRaw = nil
        self.mealLoggedAt = nil
        
        // Encode ingredients and insights as JSON
        self.ingredientsData = (try? JSONEncoder().encode(ingredients)) ?? Data()
        self.insightsData = (try? JSONEncoder().encode(insights)) ?? Data()
        self.ingredientEntities = ingredients.enumerated().map { idx, item in
            PlateIngredientEntity(name: item.name, amount: item.amount, order: idx)
        }
        self.insightEntities = insights.enumerated().map { idx, item in
            PlateInsightEntity(typeRawValue: item.type.rawValue, title: item.title, detail: item.description, order: idx)
        }
        if let micronutrients { self.microsData = try? JSONEncoder().encode(micronutrients) }
        if let connections { self.connectionsData = try? JSONEncoder().encode(connections) }
    }
    
    var ingredients: [PlateIngredient] {
        if !ingredientEntities.isEmpty {
            return ingredientEntities
                .sorted(by: { $0.order < $1.order })
                .map { PlateIngredient(name: $0.name, amount: $0.amount) }
        }
        if cachedIngredientsData != ingredientsData {
            cachedIngredients = (try? JSONDecoder().decode([PlateIngredient].self, from: ingredientsData)) ?? []
            cachedIngredientsData = ingredientsData
        }
        return cachedIngredients
    }
    
    var insights: [PlateInsight] {
        if !insightEntities.isEmpty {
            return insightEntities
                .sorted(by: { $0.order < $1.order })
                .map { $0.asPlateInsight }
        }
        if cachedInsightsData != insightsData {
            cachedInsights = (try? JSONDecoder().decode([PlateInsight].self, from: insightsData)) ?? []
            cachedInsightsData = insightsData
        }
        return cachedInsights
    }
    
    var image: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }

    var micronutrients: Micronutrients? {
        if cachedMicrosData != microsData {
            if let microsData {
                cachedMicronutrients = try? JSONDecoder().decode(Micronutrients.self, from: microsData)
            } else {
                cachedMicronutrients = nil
            }
            cachedMicrosData = microsData
        }
        return cachedMicronutrients
    }

    var connections: [String] {
        if cachedConnectionsData != connectionsData {
            if let connectionsData {
                cachedConnections = (try? JSONDecoder().decode([String].self, from: connectionsData)) ?? []
            } else {
                cachedConnections = []
            }
            cachedConnectionsData = connectionsData
        }
        return cachedConnections
    }

    var mealLogIntent: MealLogIntent? {
        get {
            guard let mealLogIntentRaw else { return nil }
            return MealLogIntent(rawValue: mealLogIntentRaw)
        }
        set {
            mealLogIntentRaw = newValue?.rawValue
        }
    }
    
    // Get Nutri-Score letter for this plate analysis
    var nutriScoreLetter: NutriScoreLetter {
        return nutriScoreForPlate(score0to10: nutritionScore)
    }
    
    // Mock data for previews
    static func mockData() -> PlateAnalysisHistory {
        let mockIngredients = [
            PlateIngredient(name: "Quinoa", amount: "100g"),
            PlateIngredient(name: "Broccoli", amount: "100g"),
            PlateIngredient(name: "Olive Oil", amount: "15ml")
        ]
        
        let mockInsights = [
            PlateInsight(
                type: .positive,
                title: "Excellent Source of Protein",
                description: "Helps with muscle repair and growth."
            ),
            PlateInsight(
                type: .suggestion,
                title: "Tip: Add More Veggies",
                description: "Consider adding bell peppers or spinach for extra vitamins."
            )
        ]
        
        return PlateAnalysisHistory(
            name: "Lunch",
            nutritionScore: 8.5,
            description: "This meal is a great source of protein and provides a balanced mix of carbs and healthy fats.",
            protein: 25,
            carbs: 40,
            fat: 20,
            calories: 450,
            ingredients: mockIngredients,
            insights: mockInsights
        )
    }
}

@Model
class PlateIngredientEntity {
    var id: UUID
    var name: String
    var amount: String
    var order: Int
    var plate: PlateAnalysisHistory?

    init(name: String, amount: String, order: Int, plate: PlateAnalysisHistory? = nil) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.order = order
        self.plate = plate
    }
}

@Model
class PlateInsightEntity {
    var id: UUID
    var typeRawValue: String
    var title: String
    var detail: String
    var order: Int
    var plate: PlateAnalysisHistory?

    init(typeRawValue: String, title: String, detail: String, order: Int, plate: PlateAnalysisHistory? = nil) {
        self.id = UUID()
        self.typeRawValue = typeRawValue
        self.title = title
        self.detail = detail
        self.order = order
        self.plate = plate
    }

    var asPlateInsight: PlateInsight {
        let type = PlateInsight.PlateInsightType(rawValue: typeRawValue) ?? .suggestion
        return PlateInsight(type: type, title: title, description: detail)
    }
}

struct PlateIngredient: Codable {
    let name: String
    let amount: String
}

struct PlateInsight: Codable {
    let type: PlateInsightType
    let title: String
    let description: String
    
    enum PlateInsightType: String, Codable {
        case positive
        case suggestion
        case warning
    }
}

// Enum to represent both product and plate entries in history
enum HistoryItemType: Identifiable {
    case product(Product)
    case plate(PlateAnalysisHistory)
    
    var id: String {
        switch self {
        case .product(let product):
            // Use a stable identifier for products based on barcode
            return "product-\(product.barcode)"
        case .plate(let plate):
            return "plate-\(plate.id.uuidString)"
        }
    }
    
    var date: Date {
        switch self {
        case .product(let product):
            return product.scannedDate
        case .plate(let plate):
            return plate.analyzedDate
        }
    }
    
    var name: String {
        switch self {
        case .product(let product):
            return product.name
        case .plate(let plate):
            return plate.name
        }
    }
    
    var nutriScoreLetter: NutriScoreLetter {
        switch self {
        case .product(let product):
            return product.nutriScoreLetter
        case .plate(let plate):
            return plate.nutriScoreLetter
        }
    }
}

extension PlateAnalysisHistory {
    var cacheKey: String {
        return "plate_\(id.uuidString)"
    }
}

// Ensure SwiftUI item sheets can bind directly to history items
extension PlateAnalysisHistory: Identifiable {}
