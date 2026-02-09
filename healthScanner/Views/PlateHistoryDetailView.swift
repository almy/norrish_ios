//
//  PlateHistoryDetailView.swift
//  healthScanner
//
//  A thin wrapper to show full plate details
//  for history items, reusing PlateDetailView.
//

import SwiftUI

struct PlateHistoryDetailView: View {
    let plateAnalysis: PlateAnalysisHistory
    let onClose: () -> Void

    init(plateAnalysis: PlateAnalysisHistory, onClose: @escaping () -> Void = {}) {
        self.plateAnalysis = plateAnalysis
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 12) {
            // Adaptive qualitative message for this plate
            if let rec = OnDeviceNutritionRecommendationEngine().qualitativeMealMessage(for: plateAnalysis) {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.title).font(.subheadline).fontWeight(.semibold)
                        Text(rec.message).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.gray.opacity(0.06))
                .cornerRadius(10)
                .padding(.horizontal, 16)
            }

            PlateDetailView(plateAnalysis: plateAnalysis, onClose: onClose)
        }
    }
}

#Preview {
    NavigationView {
        PlateHistoryDetailView(plateAnalysis: PlateAnalysisHistory.mockData())
    }
}
