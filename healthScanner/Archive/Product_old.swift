//
//  Product.swift
//  healthScanner
//
//  Created by myftiu on 06/09/25.
//

import Foundation
import SwiftData

@Model
final class Product {
    var barcode: String
    var name: String
    var brand: String
    var nutritionData: NutritionData
    var scannedDate: Date
    
    init(barcode: String, name: String, brand: String, nutritionData: NutritionData) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.nutritionData = nutritionData
        self.scannedDate = Date()
    }
}

struct NutritionData: Codable {
    let calories: Double
    let fat: Double
    let saturatedFat: Double
    let sugar: Double
    let sodium: Double
    let protein: Double
    let fiber: Double
    let carbohydrates: Double
    
    // Health score calculation (0-100)
    var healthScore: Double {
        var score = 100.0
        
        // Deduct points for high sugar (>15g per 100g)
        if sugar > 15 {
            score -= min(30, (sugar - 15) * 2)
        }
        
        // Deduct points for high saturated fat (>5g per 100g)
        if saturatedFat > 5 {
            score -= min(25, (saturatedFat - 5) * 3)
        }
        
        // Deduct points for high sodium (>1.5g per 100g)
        if sodium > 1.5 {
            score -= min(25, (sodium - 1.5) * 10)
        }
        
        // Add points for fiber (>3g per 100g)
        if fiber > 3 {
            score += min(15, (fiber - 3) * 2)
        }
        
        // Add points for protein (>10g per 100g)
        if protein > 10 {
            score += min(10, (protein - 10) * 1)
        }
        
        return max(0, min(100, score))
    }
    
    var healthLevel: HealthLevel {
        switch healthScore {
        case 70...100:
            return .green
        case 40..<70:
            return .amber
        default:
            return .red
        }
    }
}

enum HealthLevel: String, CaseIterable {
    case green = "Healthy"
    case amber = "Moderate"
    case red = "Unhealthy"
    
    var color: String {
        switch self {
        case .green: return "green"
        case .amber: return "orange"
        case .red: return "red"
        }
    }
}