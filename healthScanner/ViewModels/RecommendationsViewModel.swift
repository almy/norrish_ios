import Foundation

@MainActor
final class RecommendationsViewModel: ObservableObject {
    @Published var recommendations: [NutritionRecommendation] = []
    @Published var correlations: [CorrelationInsight] = []
    @Published var errorMessage: String?

    private let service = RecommendationService()

    func refresh(plates: [PlateAnalysisHistory], products: [Product]) async {
        do {
            let result = try await service.fetchRecommendations(plates: plates, products: products)
            recommendations = result.recommendations
            correlations = result.correlations
            errorMessage = nil
        } catch {
            recommendations = []
            correlations = []
            errorMessage = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
        }
    }
}
