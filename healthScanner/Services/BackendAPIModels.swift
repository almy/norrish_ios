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
    let mealType: String?
    let portionEstimate: BackendPortionEstimate?
    let confidenceIdentification: Double?
    let confidenceQuantity: Double?
    let confidenceOverall: Double?
    let uncertaintyNotes: [String]?
    let topAssumptions: [String]?
    let whyThisScore: [String]?
    let quickWinActions: [String]?
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
    let confidence: Double?
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
    let notable: [BackendMicronutrientNotable]?
    let summary: String?
}

struct BackendMicronutrientNotable: Codable {
    let name: String
    let amount: Double
    let unit: String
    let dailyValuePct: Int?
    let direction: String?

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case unit
        case dailyValuePct
        case daily_value_pct
        case direction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        amount = try c.decode(Double.self, forKey: .amount)
        unit = try c.decode(String.self, forKey: .unit)
        dailyValuePct = try c.decodeIfPresent(Int.self, forKey: .dailyValuePct)
            ?? c.decodeIfPresent(Int.self, forKey: .daily_value_pct)
        direction = try c.decodeIfPresent(String.self, forKey: .direction)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(amount, forKey: .amount)
        try c.encode(unit, forKey: .unit)
        try c.encodeIfPresent(dailyValuePct, forKey: .dailyValuePct)
        try c.encodeIfPresent(direction, forKey: .direction)
    }
}

struct BackendPortionEstimate: Decodable {
    let amount: Double
    let unit: String
    let confidence: Double
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

struct BackendSimilarProductsResponse: Decodable {
    let ean: String
    let results: [BackendSimilarProductItem]
}

struct BackendSimilarProductItem: Decodable {
    let ean: String
    let name: String?
    let score: Double
    let imageUrl: String?
    let reason: String?
    let allergenWarning: String?
}
