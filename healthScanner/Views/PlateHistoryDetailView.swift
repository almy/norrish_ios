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
                    Image(systemName: "lightbulb.fill").foregroundColor(.momentumAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.title)
                            .font(AppFonts.sans(12, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                        Text(rec.message)
                            .font(AppFonts.sans(11, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .cornerRadius(10)
                .padding(.horizontal, 16)
            }

            PlateDetailView(plateAnalysis: plateAnalysis, onClose: onClose)
        }
    }
}

#Preview {
    NavigationStack {
        PlateHistoryDetailView(plateAnalysis: PlateAnalysisHistory.mockData())
    }
}
