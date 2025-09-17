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

    var body: some View {
        PlateDetailView(plateAnalysis: plateAnalysis)
    }
}

#Preview {
    NavigationView {
        PlateHistoryDetailView(plateAnalysis: PlateAnalysisHistory.mockData())
    }
}

