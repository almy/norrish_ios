import SwiftUI
import SwiftData

struct RecommendationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateAnalysisHistory.analyzedDate, order: .reverse) private var plateHistory: [PlateAnalysisHistory]
    @Query(sort: \Product.scannedDate, order: .reverse) private var products: [Product]

    @StateObject private var viewModel = RecommendationsViewModel()
    @State private var insights: [PersonalizedInsight] = []

    var body: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(AppFonts.sans(12, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
            }

            if !insights.isEmpty {
                Section(header: Text("Highlights").font(AppFonts.label).foregroundColor(.nordicSlate)) {
                    ForEach(insights.indices, id: \.self) { i in
                        PersonalizedInsightCard(insight: insights[i])
                    }
                }
            }

            if !viewModel.recommendations.isEmpty {
                Section(header: Text("Recommendations").font(AppFonts.label).foregroundColor(.nordicSlate)) {
                    ForEach(viewModel.recommendations) { rec in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(rec.title)
                                    .font(AppFonts.serif(16, weight: .semibold))
                                    .foregroundColor(.midnightSpruce)
                                Spacer()
                                Text(String(format: "%.0f%%", rec.relevanceScore * 100))
                                    .font(AppFonts.sans(10, weight: .bold))
                                    .padding(4)
                                    .background(Color.nordicBone.opacity(0.8))
                                    .foregroundColor(.midnightSpruce)
                                    .cornerRadius(6)
                            }
                            Text(rec.message)
                                .font(AppFonts.sans(12, weight: .regular))
                                .foregroundColor(.nordicSlate)
                            if !rec.evidence.isEmpty {
                                ForEach(rec.evidence, id: \.self) { ev in
                                    Text("• \(ev)")
                                        .font(AppFonts.sans(11, weight: .regular))
                                        .foregroundColor(.nordicSlate)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !viewModel.correlations.isEmpty {
                Section(header: Text("Correlations").font(AppFonts.label).foregroundColor(.nordicSlate)) {
                    ForEach(viewModel.correlations) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.type.rawValue.replacingOccurrences(of: "Vs", with: " vs "))
                                .font(AppFonts.serif(16, weight: .semibold))
                                .foregroundColor(.midnightSpruce)
                            Text(c.description)
                                .font(AppFonts.sans(12, weight: .regular))
                                .foregroundColor(.nordicSlate)
                            if !c.evidence.isEmpty {
                                ForEach(c.evidence, id: \.self) { ev in
                                    Text("• \(ev)")
                                        .font(AppFonts.sans(11, weight: .regular))
                                        .foregroundColor(.nordicSlate)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Insights")
        .scrollContentBackground(.hidden)
        .background(Color.nordicBone)
        .task(id: plateHistory.first?.id) {
            // Foreground catch-up: ensure last 30 days aggregates are present
            await AggregatorService.shared.upsertMissingDays(limit: 30, modelContext: modelContext)
            await viewModel.refresh(
                plates: Array(plateHistory.prefix(50)),
                products: Array(products.prefix(100))
            )
            insights = viewModel.recommendations.prefix(8).map { $0.asPersonalizedInsight() }
        }
    }
}

#Preview {
    NavigationStack { RecommendationListView() }
}
