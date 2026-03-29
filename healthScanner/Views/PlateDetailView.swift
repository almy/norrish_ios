//
//  PlateDetailView.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftUI

struct PlateDetailView: View {
    let plateAnalysis: PlateAnalysisHistory
    let onClose: (() -> Void)?
    @State private var feedbackGiven = false
    @Environment(\.dismiss) private var dismiss
    @State private var showNutriInfo = false
    @State private var headerImage: UIImage?
    @State private var isLoadingHeaderImage = false

    init(plateAnalysis: PlateAnalysisHistory, onClose: (() -> Void)? = nil) {
        self.plateAnalysis = plateAnalysis
        self.onClose = onClose
    }

    var body: some View {
        PlateAnalysisResultView(
            analysis: asPlateAnalysis,
            image: headerImage,
            onStartNewScan: {},
            onClose: { handleClose() }
        )
        .task { await loadHeaderImageIfNeeded() }
    }
}

private extension PlateDetailView {
    var displayTitle: String {
        // Prefer analysisDescription if it looks like a short title; else fall back to name
        let t = plateAnalysis.analysisDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty && t.count <= 60 { return t }
        return plateAnalysis.name
    }
    
    var overviewText: String {
        if let pos = plateAnalysis.insights.first(where: { $0.type == .positive }) {
            return pos.description
        }
        return plateAnalysis.analysisDescription
    }
    
    var asPlateAnalysis: PlateAnalysis {
        let micros = plateAnalysis.micronutrients
        let micronutrients = Micronutrients(
            fiberG: micros?.fiberG,
            vitaminCMg: micros?.vitaminCMg,
            ironMg: micros?.ironMg,
            other: micros?.other
        )
        let ingredients: [Ingredient] = plateAnalysis.ingredients.map { Ingredient(name: $0.name, amount: $0.amount) }
        let insights: [Insight] = plateAnalysis.insights.map { p in
            let t: Insight.InsightType
            switch p.type {
            case .positive: t = .positive
            case .suggestion: t = .suggestion
            case .warning: t = .warning
            }
            return Insight(type: t, title: p.title, description: p.description)
        }
        let desc = displayTitle
        return PlateAnalysis(
            nutritionScore: plateAnalysis.nutritionScore,
            description: desc,
            macronutrients: Macronutrients(
                protein: plateAnalysis.protein,
                carbs: plateAnalysis.carbs,
                fat: plateAnalysis.fat,
                calories: plateAnalysis.calories
            ),
            ingredients: ingredients,
            insights: insights,
            micronutrients: micronutrients,
            connections: plateAnalysis.connections
        )
    }

    @MainActor
    func handleClose() {
        if let onClose { onClose() }
        dismiss()
    }

    @MainActor
    func loadHeaderImageIfNeeded() async {
        if headerImage == nil, let inline = plateAnalysis.image {
            headerImage = inline
        }

        guard headerImage == nil, !isLoadingHeaderImage else { return }

        isLoadingHeaderImage = true
        let cacheKey = plateAnalysis.cacheKey
        let inlineData = plateAnalysis.imageData
        let loaded = await PlateDetailView.loadPlateImage(cacheKey: cacheKey, inlineData: inlineData)
        if let loaded {
            headerImage = loaded
        }
        isLoadingHeaderImage = false
    }

    static func loadPlateImage(cacheKey: String, inlineData: Data?) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let cached = ImageCacheService.shared.loadImage(forKey: cacheKey) {
                    continuation.resume(returning: cached)
                    return
                }

                if let inlineData, let inlineImage = UIImage(data: inlineData) {
                    ImageCacheService.shared.saveImage(inlineImage, forKey: cacheKey)
                    continuation.resume(returning: inlineImage)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlateDetailView(plateAnalysis: PlateAnalysisHistory(
            name: "Lunch",
            nutritionScore: 8.5,
            description: "A healthy and balanced meal with good protein content.",
            protein: 25,
            carbs: 40,
            fat: 20,
            calories: 450,
            ingredients: [
                PlateIngredient(name: "Quinoa", amount: "100g"),
                PlateIngredient(name: "Broccoli", amount: "100g")
            ],
            insights: [
                PlateInsight(type: .positive, title: "Great protein source", description: "This meal provides excellent protein for muscle repair.")
            ]
        ))
    }
}
