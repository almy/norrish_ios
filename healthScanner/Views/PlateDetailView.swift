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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Main Plate Card with integrated image and details
                VStack(spacing: 0) {
                    // Plate Image
                    Group {
                        if let headerImage {
                            Image(uiImage: headerImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                        } else if isLoadingHeaderImage {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                                .overlay(ProgressView())
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.mint)
                                )
                        }
                    }

                    // Card content overlay
                    VStack(spacing: 16) {
                        // Dish name
                        Text(displayTitle)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        // Nutrition score with grade
                        HStack(spacing: 20) {
                            // Large grade letter
                            Text(plateAnalysis.nutriScoreLetter.rawValue)
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 8) {
                                // Score rating
                                Text("\(Int(plateAnalysis.nutritionScore))/10")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)

                                // Macronutrients grid
                                HStack(spacing: 16) {
                                    NutrientDot(label: "Protein", value: "\(plateAnalysis.protein)g", color: .green)
                                    NutrientDot(label: "Carbs", value: "\(plateAnalysis.carbs)g", color: .blue)
                                }

                                HStack(spacing: 16) {
                                    NutrientDot(label: "Fat", value: "\(plateAnalysis.fat)g", color: .orange)
                                    NutrientDot(label: "Calories", value: "\(plateAnalysis.calories) kcal", color: .gray)
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                .task { await loadHeaderImageIfNeeded() }
                
                // Micronutrients
                if let micros = plateAnalysis.micronutrients {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("micronutrients", comment: "Micronutrients section title"))
                            .font(.title3)
                            .fontWeight(.semibold)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            if let fiber = micros.fiberG { MicronutrientCard(name: NSLocalizedString("micronutrient.fiber", comment: "Fiber micronutrient label"), level: "\(fiber) \(NSLocalizedString("unit.grams", comment: "Grams unit"))", color: .green) }
                            if let vc = micros.vitaminCMg { MicronutrientCard(name: NSLocalizedString("micronutrient.vitamin_c", comment: "Vitamin C micronutrient label"), level: "\(vc) \(NSLocalizedString("unit.milligrams", comment: "Milligrams unit"))", color: .orange) }
                            if let iron = micros.ironMg { MicronutrientCard(name: NSLocalizedString("micronutrient.iron", comment: "Iron micronutrient label"), level: "\(iron) \(NSLocalizedString("unit.milligrams", comment: "Milligrams unit"))", color: .red) }
                        }

                        if let other = micros.other, !other.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("micronutrient.other", comment: "Other micronutrients label"))
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text(other)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                } else if let aiInsight = plateAnalysis.insights.first(where: { $0.title.contains("AI") || $0.title.contains("Nutrition Coach") }) {
                    // Fallback: parse micronutrients from AI analysis text if structured data missing
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("micronutrients", comment: "Micronutrients section title"))
                            .font(.title3)
                            .fontWeight(.semibold)

                        let micronutrients = extractMicronutrients(from: aiInsight.description)
                        if !micronutrients.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(micronutrients, id: \.name) { nutrient in
                                    MicronutrientCard(name: nutrient.name, level: nutrient.level, color: nutrient.color)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Connections
                let conns = plateAnalysis.connections
                if !conns.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("connections", comment: "Connections section title"))
                            .font(.title3)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(conns.indices, id: \.self) { idx in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(Color.blue).frame(width: 6, height: 6).padding(.top, 6)
                                    Text(conns[idx])
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Ingredient Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("ingredient.breakdown", comment: "Ingredient breakdown section title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    VStack(spacing: 0) {
                        ForEach(plateAnalysis.ingredients.indices, id: \.self) { index in
                            let ingredient = plateAnalysis.ingredients[index]
                            IngredientRow(name: ingredient.name, amount: ingredient.amount)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Insights & Suggestions
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("insights.suggestions", comment: "Insights and suggestions section title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    VStack(spacing: 12) {
                        ForEach(plateAnalysis.insights.indices, id: \.self) { index in
                            let insight = plateAnalysis.insights[index]
                            ModernInsightCard(insight: insight)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Feedback Section
                VStack(spacing: 16) {
                    Text(NSLocalizedString("feedback.question", comment: "Feedback question"))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("feedback.help_text", comment: "Feedback help text"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Button(action: {
                            feedbackGiven = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.thumbsup.fill")
                                Text(NSLocalizedString("feedback.yes", comment: "Yes feedback button"))
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(feedbackGiven ? .white : .primary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(feedbackGiven ? Color.green : Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }

                        Button(action: {
                            feedbackGiven = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.thumbsdown.fill")
                                Text(NSLocalizedString("feedback.no", comment: "No feedback button"))
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(NSLocalizedString("plate.analysis", comment: "Plate analysis navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: handleClose) {
                    Image(systemName: "chevron.backward")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: handleClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showNutriInfo) {
            NutriScoreInfoView(productBreakdown: nil, plateScore: plateAnalysis.nutritionScore)
        }
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(insight.description)
                    .font(.body)
                    .foregroundColor(.secondary)
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
            return .green
        case .suggestion:
            return .orange
        case .warning:
            return .red
        }
    }

    private var iconBackgroundColor: Color {
        switch insight.type {
        case .positive:
            return Color.green.opacity(0.2)
        case .suggestion:
            return Color.orange.opacity(0.2)
        case .warning:
            return Color.red.opacity(0.2)
        }
    }

    private var cardBackgroundColor: Color {
        switch insight.type {
        case .positive:
            return Color.green.opacity(0.05)
        case .suggestion:
            return Color.orange.opacity(0.05)
        case .warning:
            return Color.red.opacity(0.05)
        }
    }
}

struct ModernInsightCard: View {
    let insight: PlateInsight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(textColor)

                Text(insight.description)
                    .font(.body)
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
            return colorScheme == .dark ? .green : .white
        case .suggestion:
            return colorScheme == .dark ? .orange : .white
        case .warning:
            return colorScheme == .dark ? .red : .white
        }
    }

    private var backgroundColor: Color {
        switch insight.type {
        case .positive:
            return colorScheme == .dark
                ? Color.green.opacity(0.2)
                : Color.green.opacity(0.8)
        case .suggestion:
            return colorScheme == .dark
                ? Color.orange.opacity(0.2)
                : Color.orange.opacity(0.8)
        case .warning:
            return colorScheme == .dark
                ? Color.red.opacity(0.2)
                : Color.red.opacity(0.8)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
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
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(level)
                .font(.caption)
                .foregroundColor(.secondary)
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
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(value)
                .font(.caption.weight(.semibold))
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
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Text(amount)
                .font(.body)
                .foregroundColor(.secondary)
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
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text(value).font(.system(size: 28, weight: .bold)).foregroundColor(.primary)
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
        ("Vitamin C", ["vitamin c", "ascorbic acid", "citrus", "antioxidant"], "mg", .orange),
        ("Vitamin A", ["vitamin a", "beta carotene", "carotenoids"], "µg", .yellow),
        ("Vitamin K", ["vitamin k", "leafy greens"], "µg", .green),
        ("Vitamin E", ["vitamin e", "tocopherol"], "mg", .purple),
        ("B Vitamins", ["vitamin b", "b vitamins", "folate", "niacin", "thiamine"], "mg", .blue),
        ("Fiber", ["fiber", "fibre", "dietary fiber"], "g", .brown),
        ("Iron", ["iron", "heme iron"], "mg", .red),
        ("Calcium", ["calcium", "bone health"], "mg", .gray),
        ("Potassium", ["potassium", "electrolytes"], "mg", .pink),
        ("Magnesium", ["magnesium"], "mg", .mint),
        ("Zinc", ["zinc"], "mg", .indigo),
        ("Omega-3", ["omega", "fatty acids", "omega-3"], "g", .teal),
        ("Antioxidants", ["antioxidants", "polyphenols", "flavonoids"], "", .purple)
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
            micronutrients.append(Micronutrient(name: "Vitamins", level: "Rich", color: .green))
        }
        if lowercaseText.contains("protein") {
            micronutrients.append(Micronutrient(name: "Amino Acids", level: "Complete", color: .blue))
        }
        if lowercaseText.contains("whole grain") || lowercaseText.contains("fiber") {
            micronutrients.append(Micronutrient(name: "Fiber", level: "Good", color: .brown))
        }
        if lowercaseText.contains("healthy fats") || lowercaseText.contains("omega") {
            micronutrients.append(Micronutrient(name: "Healthy Fats", level: "Present", color: .teal))
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
