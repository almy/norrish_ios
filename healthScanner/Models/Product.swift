//
//  Product.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Product {
    var barcode: String
    var name: String
    var brand: String
    var nutritionData: NutritionData
    var scannedDate: Date
    var imageURL: String?
    var localImagePath: String? // Persisted path to cached image
    var categoriesTags: [String]? // OFF categories tags (e.g., ["en:beverages", "en:cheeses"])
    var ingredients: String? // Product ingredients list 
    var mealLogIntentRaw: String?
    var mealLoggedAt: Date?
    
    init(barcode: String, name: String, brand: String, nutritionData: NutritionData, imageURL: String? = nil, localImagePath: String? = nil, categoriesTags: [String]? = nil, ingredients: String? = nil, mealLogIntentRaw: String? = nil, mealLoggedAt: Date? = nil) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.nutritionData = nutritionData
        self.scannedDate = Date()
        self.imageURL = imageURL
        self.localImagePath = localImagePath
        self.categoriesTags = categoriesTags
        self.ingredients = ingredients
        self.mealLogIntentRaw = mealLogIntentRaw
        self.mealLoggedAt = mealLoggedAt
    }

    // Get Nutri-Score letter for this product
    var nutriScoreLetter: NutriScoreLetter {
        return nutriScoreForProduct(self)
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
    let fruitsVegetablesNutsPercent: Double?
    
}

extension Product {
        static var sampleProduct: Product {
            let sampleNutrition = NutritionData(
                calories: 250,
                fat: 8.5,
                saturatedFat: 3.2,
                sugar: 12.0,
                sodium: 0.8,
                protein: 15.0,
                fiber: 4.5,
                carbohydrates: 35.0,
                fruitsVegetablesNutsPercent: nil
            )
            
            return Product(
                barcode: "1234567890123",
                name: "Sample Cereal",
                brand: "Healthy Foods Co.",
                nutritionData: sampleNutrition,
                imageURL: "https://example.com/sample-image.jpg",
                localImagePath: nil,
                categoriesTags: ["en:cereals"],
                ingredients: "Whole grain oats, sugar, salt, wheat flour"
            )
        }
    }
