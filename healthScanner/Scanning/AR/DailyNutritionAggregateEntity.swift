import SwiftData
import Foundation

@Model
final class DailyNutritionAggregateEntity {
    @Attribute(.unique) var id: UUID
    var date: Date
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        calories: Double = 0.0,
        proteinGrams: Double = 0.0,
        carbsGrams: Double = 0.0,
        fatGrams: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }
}
