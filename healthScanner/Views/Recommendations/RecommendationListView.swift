import SwiftUI
import SwiftData

struct RecommendationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateAnalysisHistory.analyzedDate, order: .reverse) private var plateHistory: [PlateAnalysisHistory]
    @Query(sort: \Product.scannedDate, order: .reverse) private var products: [Product]

    @StateObject private var engine = OnDeviceNutritionRecommendationEngine()
    @State private var insights: [PersonalizedInsight] = []

    var body: some View {
        List {
            if !insights.isEmpty {
                Section(header: Text("Highlights")) {
                    ForEach(insights.indices, id: \.self) { i in
                        PersonalizedInsightCard(insight: insights[i])
                    }
                }
            }

            if !engine.currentRecommendations.isEmpty {
                Section(header: Text("Recommendations")) {
                    ForEach(engine.currentRecommendations) { rec in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(rec.title).font(.headline)
                                Spacer()
                                Text(String(format: "%.0f%%", rec.relevanceScore * 100))
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(6)
                            }
                            Text(rec.message).font(.subheadline).foregroundStyle(.secondary)
                            if !rec.evidence.isEmpty {
                                ForEach(rec.evidence, id: \.self) { ev in
                                    Text("• \(ev)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !engine.currentCorrelations.isEmpty {
                Section(header: Text("Correlations")) {
                    ForEach(engine.currentCorrelations) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.type.rawValue.replacingOccurrences(of: "Vs", with: " vs "))
                                .font(.headline)
                            Text(c.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !c.evidence.isEmpty {
                                ForEach(c.evidence, id: \.self) { ev in
                                    Text("• \(ev)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Insights")
        .task(id: plateHistory.first?.id) {
            // Recompute when history changes
            let recs = await engine.generateRecommendations(plates: Array(plateHistory.prefix(50)), products: Array(products.prefix(100)))
            insights = recs.prefix(8).map { $0.asPersonalizedInsight() }
        }
    }
}

#Preview {
    NavigationView { RecommendationListView() }
}

