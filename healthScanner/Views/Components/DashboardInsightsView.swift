import SwiftUI
import SwiftData

// Fetches backend recommendations and renders them in the existing carousel UI.
struct DashboardInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateAnalysisHistory.analyzedDate, order: .reverse) private var plateHistory: [PlateAnalysisHistory]
    @Query(sort: \Product.scannedDate, order: .reverse) private var products: [Product]

    @StateObject private var viewModel = RecommendationsViewModel()
    @State private var insights: [PersonalizedInsight] = []

    var body: some View {
        PersonalizedInsightCarousel(insights: insights)
            .task(id: refreshKey) {
                await viewModel.refresh(
                    plates: Array(plateHistory.prefix(60)),
                    products: Array(products.prefix(120))
                )
                insights = viewModel.recommendations.map { $0.asPersonalizedInsight() }
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
