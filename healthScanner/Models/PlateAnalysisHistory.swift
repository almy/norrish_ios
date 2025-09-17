//
//  PlateAnalysisHistory.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftData
import Foundation
import UIKit

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
    var ingredientsData: Data // JSON encoded ingredients
    var insightsData: Data // JSON encoded insights
    var microsData: Data? // JSON encoded Micronutrients
    var connectionsData: Data? // JSON encoded [String]
    
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
        
        // Encode ingredients and insights as JSON
        self.ingredientsData = (try? JSONEncoder().encode(ingredients)) ?? Data()
        self.insightsData = (try? JSONEncoder().encode(insights)) ?? Data()
        if let micronutrients { self.microsData = try? JSONEncoder().encode(micronutrients) }
        if let connections { self.connectionsData = try? JSONEncoder().encode(connections) }
    }
    
    var ingredients: [PlateIngredient] {
        (try? JSONDecoder().decode([PlateIngredient].self, from: ingredientsData)) ?? []
    }
    
    var insights: [PlateInsight] {
        (try? JSONDecoder().decode([PlateInsight].self, from: insightsData)) ?? []
    }
    
    var image: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }

    var micronutrients: Micronutrients? {
        guard let microsData else { return nil }
        return try? JSONDecoder().decode(Micronutrients.self, from: microsData)
    }

    var connections: [String] {
        guard let connectionsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: connectionsData)) ?? []
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
