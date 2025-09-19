//
//  PlateAnalysisResultView.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftUI

struct PlateAnalysisResultView: View {
    let analysis: PlateAnalysis
    let image: UIImage?
    let onStartNewScan: () -> Void
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackGiven = false
    @State private var showNutriInfo = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with back button
                    HStack {
                        Button(action: { onClose(); dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text("Plate Analysis").font(.title2).fontWeight(.semibold)
                        Spacer()
                        Button(action: { onClose(); dismiss() }) {
                            Image(systemName: "xmark.circle.fill").font(.title2).opacity(0.6)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Main Plate Card with integrated image and details
                    VStack(spacing: 0) {
                        // Plate Image
                        Group {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
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
                            Text(analysis.description)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            // Nutrition score with grade
                            HStack(spacing: 20) {
                                // Large grade letter
                                Text(nutriScoreForPlate(score0to10: analysis.nutritionScore).rawValue)
                                    .font(.system(size: 64, weight: .bold))
                                    .foregroundColor(.green)

                                VStack(alignment: .leading, spacing: 8) {
                                    // Score rating
                                    Text("\(Int(analysis.nutritionScore))/10")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)

                                    // Macronutrients grid
                                    HStack(spacing: 16) {
                                        ResultNutrientDot(label: "Protein", value: "\(analysis.macronutrients.protein)g", color: .green)
                                        ResultNutrientDot(label: "Carbs", value: "\(analysis.macronutrients.carbs)g", color: .blue)
                                    }

                                    HStack(spacing: 16) {
                                        ResultNutrientDot(label: "Fat", value: "\(analysis.macronutrients.fat)g", color: .orange)
                                        ResultNutrientDot(label: "Calories", value: "\(analysis.macronutrients.calories) kcal", color: .gray)
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
                    .sheet(isPresented: $showNutriInfo) {
                        NutriScoreInfoView(productBreakdown: nil, plateScore: analysis.nutritionScore)
                    }

                    // Micronutrients
                    if let micros = analysis.micronutrients {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Micronutrients")
                                .font(.title3)
                                .fontWeight(.semibold)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                if let fiber = micros.fiberG {
                                    MicronutrientCard(name: "Fiber", level: "\(fiber) g", color: .green)
                                }
                                if let vc = micros.vitaminCMg {
                                    MicronutrientCard(name: "Vitamin C", level: "\(vc) mg", color: .orange)
                                }
                                if let iron = micros.ironMg {
                                    MicronutrientCard(name: "Iron", level: "\(iron) mg", color: .red)
                                }
                            }

                            if let other = micros.other, !other.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Other")
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
                    }

                    // Connections
                    if let connections = analysis.connections, !connections.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connections")
                                .font(.title3)
                                .fontWeight(.semibold)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(connections.indices, id: \.self) { idx in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle().fill(Color.blue).frame(width: 6, height: 6).padding(.top, 6)
                                        Text(connections[idx])
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
                        Text("Ingredient Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        VStack(spacing: 0) {
                            ForEach(analysis.ingredients.indices, id: \.self) { index in
                                let ingredient = analysis.ingredients[index]
                                ResultIngredientRow(name: ingredient.name, amount: ingredient.amount)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Insights & Suggestions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Insights & Suggestions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            ForEach(analysis.insights.indices, id: \.self) { index in
                                let insight = analysis.insights[index]
                                ResultModernInsightCard(insight: insight)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Feedback Section
                    VStack(spacing: 16) {
                        Text("Is this analysis correct?")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        Text("Your feedback helps us improve our AI.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button(action: {
                                feedbackGiven = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "hand.thumbsup.fill")
                                    Text("Yes")
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
                                    Text("No")
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
                    
                    Button(action: {
                        onStartNewScan()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start New Scan")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}

struct InsightCard: View {
    let insight: Insight
    
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

// MARK: - Score Ring
struct ScoreRingView: View {
    let score: Double // 0..10

    private var color: Color {
        let rgb = nutriScoreLetter.color
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    private var nutriScoreLetter: NutriScoreLetter {
        return nutriScoreForPlate(score0to10: score)
    }

    private var label: String {
        return String(format: NSLocalizedString("nutriscore.grade", comment: "Nutri-Score grade format"), nutriScoreLetter.rawValue)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                .frame(width: 200, height: 200)
            Circle()
                .trim(from: 0, to: min(max(score/10.0, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 36, weight: .bold))
                    Text("/10")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Text(label)
                    .font(.headline)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Helpers
private struct ResultMacroCard: View {
    let title: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle().fill(color.opacity(0.25)).frame(width: 12, height: 12)
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                Spacer()
            }
            HStack {
                Text(value).font(.system(size: 28, weight: .bold)).foregroundColor(.primary)
                Spacer()
            }
        }
        .padding()
        .frame(minHeight: 96)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1))
    }
}

struct ResultNutrientDot: View {
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

struct ResultIngredientRow: View {
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

struct ResultModernInsightCard: View {
    let insight: Insight
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

private extension PlateAnalysisResultView {
    var overviewText: String {
        if let pos = analysis.insights.first(where: { $0.type == .positive }) {
            return pos.description
        }
        let m = analysis.macronutrients
        return "Approx. P \(m.protein)g • C \(m.carbs)g • F \(m.fat)g • \(m.calories) kcal"
    }
}

#Preview {
    PlateAnalysisResultView(analysis: PlateAnalysis.mockAnalysis(), image: nil, onStartNewScan: {}, onClose: {})
}
