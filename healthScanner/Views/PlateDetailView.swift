//
//  PlateDetailView.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftUI

// Data structure for micronutrients extracted from AI analysis
struct Micronutrient {
    let name: String
    let level: String
    let color: Color
}

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

struct PlateInsightCard: View {
    let insight: PlateInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 32, height: 32)

                Image(systemName: iconName)
                    .font(AppFonts.sans(14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(AppFonts.serif(15, weight: .semibold))
                    .foregroundColor(.midnightSpruce)

                Text(insight.description)
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }

            Spacer()
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
    }

    private var iconName: String {
        switch insight.type {
        case .positive:
            return "checkmark.circle"
        case .suggestion:
            return "lightbulb"
        case .warning:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch insight.type {
        case .positive:
            return .mossInsight
        case .suggestion:
            return .momentumAmber
        case .warning:
            return .midnightSpruce
        }
    }

    private var iconBackgroundColor: Color {
        switch insight.type {
        case .positive:
            return Color.mossInsight.opacity(0.2)
        case .suggestion:
            return Color.momentumAmber.opacity(0.2)
        case .warning:
            return Color.midnightSpruce.opacity(0.2)
        }
    }

    private var cardBackgroundColor: Color {
        switch insight.type {
        case .positive:
            return Color.mossInsight.opacity(0.08)
        case .suggestion:
            return Color.momentumAmber.opacity(0.08)
        case .warning:
            return Color.midnightSpruce.opacity(0.08)
        }
    }
}

struct ModernInsightCard: View {
    let insight: PlateInsight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(AppFonts.serif(18, weight: .semibold))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(AppFonts.serif(15, weight: .semibold))
                    .foregroundColor(textColor)

                Text(insight.description)
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(descriptionColor)
            }

            Spacer()
        }
        .padding(16)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var iconName: String {
        switch insight.type {
        case .positive:
            return "checkmark.circle.fill"
        case .suggestion:
            return "lightbulb.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch insight.type {
        case .positive:
            return colorScheme == .dark ? .mossInsight : .white
        case .suggestion:
            return colorScheme == .dark ? .momentumAmber : .white
        case .warning:
            return colorScheme == .dark ? .midnightSpruce : .white
        }
    }

    private var backgroundColor: Color {
        switch insight.type {
        case .positive:
            return colorScheme == .dark
                ? Color.mossInsight.opacity(0.2)
                : Color.mossInsight.opacity(0.85)
        case .suggestion:
            return colorScheme == .dark
                ? Color.momentumAmber.opacity(0.2)
                : Color.momentumAmber.opacity(0.85)
        case .warning:
            return colorScheme == .dark
                ? Color.midnightSpruce.opacity(0.2)
                : Color.midnightSpruce.opacity(0.85)
        }
    }

    private var textColor: Color {
        switch insight.type {
        case .positive, .suggestion, .warning:
            return colorScheme == .dark ? .primary : .white
        }
    }

    private var descriptionColor: Color {
        switch insight.type {
        case .positive, .suggestion, .warning:
            return colorScheme == .dark ? .secondary : Color.white.opacity(0.9)
        }
    }
}

// Old card retained for other screens if needed
struct MacronutrientCard: View {
    let title: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(AppFonts.sans(13, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(AppFonts.serif(26, weight: .bold))
                    .foregroundColor(.midnightSpruce)
                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct MicronutrientCard: View {
    let name: String
    let level: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(AppFonts.sans(12, weight: .medium))
                .foregroundColor(.midnightSpruce)

            Text(level)
                .font(AppFonts.sans(11, weight: .regular))
                .foregroundColor(.nordicSlate)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NutrientDot: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(value)
                .font(AppFonts.sans(11, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct IngredientRow: View {
    let name: String
    let amount: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(name)
                .font(AppFonts.sans(12, weight: .regular))
                .foregroundColor(.midnightSpruce)

            Spacer()

            Text(amount)
                .font(AppFonts.sans(12, weight: .regular))
                .foregroundColor(.nordicSlate)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            colorScheme == .dark
                ? Color(.systemGray6)
                : Color(.systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.05),
                    lineWidth: 1
                )
        )
        .padding(.bottom, 8)
    }
}

// New macro card style for PlateDetail
struct PlateMacroCard: View {
    let title: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle().fill(color.opacity(0.2)).frame(width: 12, height: 12)
                Text(title).font(AppFonts.sans(13, weight: .semibold)).foregroundColor(.midnightSpruce)
                Spacer()
            }
            HStack {
                Text(value).font(AppFonts.serif(26, weight: .bold)).foregroundColor(.midnightSpruce)
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1))
    }
}

#Preview {
    NavigationView {
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

// Helper function to extract micronutrients from AI analysis text
func extractMicronutrients(from text: String) -> [Micronutrient] {
    var micronutrients: [Micronutrient] = []
    let lowercaseText = text.lowercased()
    
    // Define micronutrient keywords and their associated information
    let nutrientKeywords: [(name: String, keywords: [String], unit: String, color: Color)] = [
        ("Vitamin C", ["vitamin c", "ascorbic acid", "citrus", "antioxidant"], "mg", .momentumAmber),
        ("Vitamin A", ["vitamin a", "beta carotene", "carotenoids"], "µg", .nordicSlate),
        ("Vitamin K", ["vitamin k", "leafy greens"], "µg", .mossInsight),
        ("Vitamin E", ["vitamin e", "tocopherol"], "mg", .midnightSpruce),
        ("B Vitamins", ["vitamin b", "b vitamins", "folate", "niacin", "thiamine"], "mg", .nordicSlate),
        ("Fiber", ["fiber", "fibre", "dietary fiber"], "g", .mossInsight),
        ("Iron", ["iron", "heme iron"], "mg", .midnightSpruce),
        ("Calcium", ["calcium", "bone health"], "mg", .nordicSlate),
        ("Potassium", ["potassium", "electrolytes"], "mg", .momentumAmber),
        ("Magnesium", ["magnesium"], "mg", .mossInsight),
        ("Zinc", ["zinc"], "mg", .midnightSpruce),
        ("Omega-3", ["omega", "fatty acids", "omega-3"], "g", .nordicSlate),
        ("Antioxidants", ["antioxidants", "polyphenols", "flavonoids"], "", .momentumAmber)
    ]
    
    // Check for each nutrient in the AI text
    for nutrient in nutrientKeywords {
        let found = nutrient.keywords.contains { keyword in
            lowercaseText.contains(keyword)
        }
        
        if found {
            // Determine level based on context
            let level = determineNutrientLevel(for: nutrient.name, in: text, unit: nutrient.unit)
            micronutrients.append(Micronutrient(
                name: nutrient.name,
                level: level,
                color: nutrient.color
            ))
        }
    }
    
    // If no specific nutrients found, extract general nutritional qualities
    if micronutrients.isEmpty {
        if lowercaseText.contains("vegetables") || lowercaseText.contains("greens") {
            micronutrients.append(Micronutrient(name: "Vitamins", level: "Rich", color: .mossInsight))
        }
        if lowercaseText.contains("protein") {
            micronutrients.append(Micronutrient(name: "Amino Acids", level: "Complete", color: .nordicSlate))
        }
        if lowercaseText.contains("whole grain") || lowercaseText.contains("fiber") {
            micronutrients.append(Micronutrient(name: "Fiber", level: "Good", color: .mossInsight))
        }
        if lowercaseText.contains("healthy fats") || lowercaseText.contains("omega") {
            micronutrients.append(Micronutrient(name: "Healthy Fats", level: "Present", color: .nordicSlate))
        }
    }
    
    return Array(micronutrients.prefix(6)) // Limit to 6 for display
}

// Helper function to determine nutrient level based on context
func determineNutrientLevel(for nutrient: String, in text: String, unit: String) -> String {
    let lowercaseText = text.lowercased()
    
    // Look for positive indicators
    let positiveWords = ["rich", "excellent", "high", "abundant", "good source", "plenty"]
    let negativeWords = ["low", "lacking", "limited", "insufficient", "poor"]
    
    let hasPositive = positiveWords.contains { lowercaseText.contains($0) }
    let hasNegative = negativeWords.contains { lowercaseText.contains($0) }
    
    if hasPositive && !hasNegative {
        return unit.isEmpty ? "Rich" : "High"
    } else if hasNegative {
        return unit.isEmpty ? "Low" : "Limited"
    } else {
        return unit.isEmpty ? "Present" : "Moderate"
    }
}
