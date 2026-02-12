import Foundation

struct SimilarProductSuggestion: Identifiable, Codable, Equatable {
    // Unique identifier (could be barcode/EAN)
    var id: String { ean }
    let ean: String
    let name: String
    let score: Double? // Added score property
    let imageUrl: String?
    let reason: String?
    let allergenWarning: String?
    
    // Optionally, add brand, nutrition, or other fields as needed.
    // let brand: String?
    // let nutrition: NutritionData?
    
    init(ean: String, name: String, score: Double? = nil, imageUrl: String? = nil, reason: String? = nil, allergenWarning: String? = nil) {
        self.ean = ean
        self.name = name
        self.score = score
        self.imageUrl = imageUrl
        self.reason = reason
        self.allergenWarning = allergenWarning
    }
}
