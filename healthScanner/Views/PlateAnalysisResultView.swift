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
                    
                    // Plate Image
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 220)
                                .overlay(
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.mint)
                                )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Title (centered)
                    Text(analysis.description)
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)

                    // Score ring
                    HStack {
                        Spacer()
                        ScoreRingView(score: analysis.nutritionScore)
                        Spacer()
                    }
                    .padding(.bottom, 4)

                    // Nutri-Score badge
                    HStack {
                        Spacer()
                        NutriScoreBadge(letter: nutriScoreForPlate(score0to10: analysis.nutritionScore), compact: false)
                        Button {
                            showNutriInfo = true
                        } label: {
                            Image(systemName: "info.circle").foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    .sheet(isPresented: $showNutriInfo) {
                        NutriScoreInfoView(productBreakdown: nil, plateScore: analysis.nutritionScore)
                    }

                    // Nutrition Overview card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition Overview")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(overviewText)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    
                    // Macronutrients — styled like the reference
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Macronutrients")
                            .font(.title3)
                            .fontWeight(.semibold)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ResultMacroCard(title: "Protein", value: "\(analysis.macronutrients.protein)g", color: .green)
                            ResultMacroCard(title: "Carbs", value: "\(analysis.macronutrients.carbs)g", color: .blue)
                            ResultMacroCard(title: "Fat", value: "\(analysis.macronutrients.fat)g", color: .orange)
                            ResultMacroCard(title: "Calories", value: "\(analysis.macronutrients.calories) kcal", color: .purple)
                        }
                    }
                    .padding(.horizontal, 20)

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
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            ForEach(analysis.ingredients.indices, id: \.self) { index in
                                let ingredient = analysis.ingredients[index]
                                HStack {
                                    Text(ingredient.name)
                                        .font(.body)
                                    Spacer()
                                    Text(ingredient.amount)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                
                                if index < analysis.ingredients.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Insights & Suggestions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Insights & Suggestions")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            ForEach(analysis.insights.indices, id: \.self) { index in
                                let insight = analysis.insights[index]
                                InsightCard(insight: insight)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Feedback Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Is this analysis correct?")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Your feedback helps us improve our AI.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                feedbackGiven = true
                            }) {
                                HStack {
                                    Image(systemName: "hand.thumbsup")
                                    Text("Yes")
                                }
                                .font(.body)
                                .foregroundColor(feedbackGiven ? .white : .primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(feedbackGiven ? Color.green : Color.gray.opacity(0.1))
                                .cornerRadius(20)
                            }
                            
                            Button(action: {
                                feedbackGiven = true
                            }) {
                                HStack {
                                    Image(systemName: "hand.thumbsdown")
                                    Text("No")
                                }
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(20)
                            }
                            
                            Spacer()
                        }
                    }
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
