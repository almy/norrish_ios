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
        PlateDetailView(plateAnalysis: plateAnalysis, onClose: onClose)
    }
}

#Preview {
    NavigationView {
        PlateHistoryDetailView(plateAnalysis: PlateAnalysisHistory.mockData())
    }
}
