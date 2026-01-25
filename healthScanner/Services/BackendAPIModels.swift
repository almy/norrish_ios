import Foundation

struct BackendBarcodeRequest: Encodable {
    let barcode: String
    let locale: String?
}

struct BackendBarcodeResponse: Decodable {
    let scanId: String
    let status: String
    let product: BackendProductPayload
}

struct BackendProductPayload: Decodable {
    let barcode: String
    let name: String
    let brand: String
    let nutritionData: BackendNutritionData
    let imageURL: String?
    let categoriesTags: [String]?
    let ingredients: String?
    let scannedDate: String?
}

struct BackendNutritionData: Codable {
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


struct BackendPlateScanResponse: Decodable {
    let scanId: String
    let status: String
    let analysis: BackendPlateAnalysis
}

struct BackendPlateAnalysis: Decodable {
    let nutritionScore: Double
    let description: String
    let macronutrients: BackendMacronutrients
    let ingredients: [BackendPlateIngredient]
    let insights: [BackendPlateInsight]
    let micronutrients: BackendMicronutrients?
    let connections: [String]?
}

struct BackendMacronutrients: Decodable {
    let protein: Int
    let carbs: Int
    let fat: Int
    let calories: Int
}

struct BackendPlateIngredient: Codable {
    let name: String
    let amount: String
}

struct BackendPlateInsight: Codable {
    let type: String
    let title: String
    let description: String
}

struct BackendMicronutrients: Codable {
    let fiberG: Int?
    let vitaminCMg: Int?
    let ironMg: Int?
    let other: String?
}

struct BackendRecommendationsRequest: Encodable {
    let plates: [BackendPlateHistoryPayload]
    let products: [BackendProductHistoryPayload]
    let preferences: BackendDietaryPreferencesPayload
    let mode: String?
}

struct BackendPlateHistoryPayload: Encodable {
    let id: String
    let name: String
    let analyzedDate: String
    let nutritionScore: Double
    let description: String
    let protein: Int
    let carbs: Int
    let fat: Int
    let calories: Int
    let ingredients: [BackendPlateIngredient]
    let insights: [BackendPlateInsight]
    let micronutrients: BackendMicronutrients?
    let connections: [String]?
}

struct BackendProductHistoryPayload: Encodable {
    let barcode: String
    let name: String
    let brand: String
    let nutritionData: BackendNutritionData
    let scannedDate: String
    let categoriesTags: [String]?
    let ingredients: String?
}

struct BackendDietaryPreferencesPayload: Encodable {
    let selectedAllergies: [String]
    let selectedDietaryRestrictions: [String]
    let customAllergies: [String]
    let customRestrictions: [String]
}

struct BackendRecommendationsResponse: Decodable {
    let recommendations: [BackendNutritionRecommendationPayload]
    let correlations: [BackendCorrelationInsightPayload]
}

struct BackendNutritionRecommendationPayload: Decodable {
    let id: String
    let title: String
    let message: String
    let reason: String
    let relevanceScore: Double
    let type: String
    let tags: [String]
    let evidence: [String]
}

struct BackendCorrelationInsightPayload: Decodable {
    let id: String
    let type: String
    let description: String
    let score: Double
    let tags: [String]
    let evidence: [String]
}
