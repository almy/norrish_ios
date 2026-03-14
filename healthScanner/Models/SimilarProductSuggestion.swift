import Foundation

struct SimilarProductSuggestion: Identifiable, Codable, Equatable {
    var id: String { ean }
    let ean: String
    let name: String
    let score: Double?
    let imageUrl: String?
    let category: String?
    let nutriScore: String?
    let reason: String?
    let allergenWarning: String?

    init(
        ean: String,
        name: String,
        score: Double? = nil,
        imageUrl: String? = nil,
        category: String? = nil,
        nutriScore: String? = nil,
        reason: String? = nil,
        allergenWarning: String? = nil
    ) {
        self.ean = ean
        self.name = name
        self.score = score
        self.imageUrl = imageUrl
        self.category = category
        self.nutriScore = nutriScore
        self.reason = reason
        self.allergenWarning = allergenWarning
    }
}
