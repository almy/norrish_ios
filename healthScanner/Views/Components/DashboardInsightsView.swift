import SwiftUI
import SwiftData

// Generates on-device recommendations and renders them in the existing carousel UI.
struct DashboardInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateAnalysisHistory.analyzedDate, order: .reverse) private var plateHistory: [PlateAnalysisHistory]
    @Query(sort: \Product.scannedDate, order: .reverse) private var products: [Product]

    @StateObject private var engine = OnDeviceNutritionRecommendationEngine()
    @State private var insights: [PersonalizedInsight] = []

    var body: some View {
        PersonalizedInsightCarousel(insights: insights)
            .task(id: refreshKey) {
                let recs = await engine.generateRecommendations(
                    plates: Array(plateHistory.prefix(60)),
                    products: Array(products.prefix(120))
                )
                // Use all generated recommendations (mapped to insights)
                insights = recs.map { $0.asPersonalizedInsight() }
            }
    }

    private var refreshKey: String {
        let p1 = plateHistory.first?.id.uuidString ?? "-"
        let p2 = products.first?.barcode ?? "-"
        return "\(p1)-\(p2)-\(plateHistory.count)-\(products.count)"
    }
}

#Preview {
    DashboardInsightsView()
}

