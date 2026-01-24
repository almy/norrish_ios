import Foundation

final class RecommendationService {
    private let apiClient = BackendAPIClient.shared
    private let dateFormatter = ISO8601DateFormatter()

    func fetchRecommendations(
        plates: [PlateAnalysisHistory],
        products: [Product],
        preferences: DietaryPreferencesManager = .shared,
        mode: String? = "ml"
    ) async throws -> (recommendations: [NutritionRecommendation], correlations: [CorrelationInsight]) {
        let payload = BackendRecommendationsRequest(
            plates: plates.map { makePlatePayload(from: $0) },
            products: products.map { makeProductPayload(from: $0) },
            preferences: makePreferencesPayload(from: preferences),
            mode: mode
        )

        let response: BackendRecommendationsResponse = try await apiClient.post(
            endpoint: apiClient.endpoints.recommendations,
            body: payload
        )

        let recommendations = response.recommendations.map { mapRecommendation($0) }
        let correlations = response.correlations.map { mapCorrelation($0) }
        return (recommendations, correlations)
    }

    private func makePlatePayload(from plate: PlateAnalysisHistory) -> BackendPlateHistoryPayload {
        let ingredients = plate.ingredients.map { BackendPlateIngredient(name: $0.name, amount: $0.amount) }
        let insights = plate.insights.map {
            BackendPlateInsight(type: $0.type.rawValue, title: $0.title, description: $0.description)
        }

        return BackendPlateHistoryPayload(
            id: plate.id.uuidString,
            name: plate.name,
            analyzedDate: dateFormatter.string(from: plate.analyzedDate),
            nutritionScore: plate.nutritionScore,
            description: plate.analysisDescription,
            protein: plate.protein,
            carbs: plate.carbs,
            fat: plate.fat,
            calories: plate.calories,
            ingredients: ingredients,
            insights: insights,
            micronutrients: mapMicronutrients(plate.micronutrients),
            connections: plate.connections
        )
    }

    private func makeProductPayload(from product: Product) -> BackendProductHistoryPayload {
        let nutrition = BackendNutritionData(
            calories: product.nutritionData.calories,
            fat: product.nutritionData.fat,
            saturatedFat: product.nutritionData.saturatedFat,
            sugar: product.nutritionData.sugar,
            sodium: product.nutritionData.sodium,
            protein: product.nutritionData.protein,
            fiber: product.nutritionData.fiber,
            carbohydrates: product.nutritionData.carbohydrates,
            fruitsVegetablesNutsPercent: product.nutritionData.fruitsVegetablesNutsPercent
        )

        return BackendProductHistoryPayload(
            barcode: product.barcode,
            name: product.name,
            brand: product.brand,
            nutritionData: nutrition,
            scannedDate: dateFormatter.string(from: product.scannedDate),
            categoriesTags: product.categoriesTags,
            ingredients: product.ingredients
        )
    }

    private func makePreferencesPayload(from preferences: DietaryPreferencesManager) -> BackendDietaryPreferencesPayload {
        BackendDietaryPreferencesPayload(
            selectedAllergies: preferences.selectedAllergies.map { $0.rawValue },
            selectedDietaryRestrictions: preferences.selectedDietaryRestrictions.map { $0.rawValue },
            customAllergies: preferences.customAllergies,
            customRestrictions: preferences.customRestrictions
        )
    }

    private func mapMicronutrients(_ micros: Micronutrients?) -> BackendMicronutrients? {
        guard let micros else { return nil }
        return BackendMicronutrients(
            fiberG: micros.fiberG,
            vitaminCMg: micros.vitaminCMg,
            ironMg: micros.ironMg,
            other: micros.other
        )
    }

    private func mapRecommendation(_ payload: BackendNutritionRecommendationPayload) -> NutritionRecommendation {
        let type = NutritionRecommendation.RecommendationType(rawValue: payload.type) ?? .habitPattern
        let id = UUID(uuidString: payload.id) ?? UUID()

        return NutritionRecommendation(
            id: id,
            title: payload.title,
            message: payload.message,
            reason: payload.reason,
            relevanceScore: payload.relevanceScore,
            type: type,
            tags: payload.tags,
            evidence: payload.evidence
        )
    }

    private func mapCorrelation(_ payload: BackendCorrelationInsightPayload) -> CorrelationInsight {
        let type = CorrelationInsight.CorrelationType(rawValue: payload.type) ?? .categoryHabit
        let id = UUID(uuidString: payload.id) ?? UUID()

        return CorrelationInsight(
            id: id,
            type: type,
            description: payload.description,
            score: payload.score,
            tags: payload.tags,
            evidence: payload.evidence
        )
    }
}
