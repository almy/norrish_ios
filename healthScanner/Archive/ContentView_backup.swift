//
//  PlateDetailView.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftUI

struct PlateDetailView: View {
    let plateAnalysis: PlateAnalysisHistory
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackGiven = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Plate Analysis")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Plate Image
                VStack {
                    if let image = plateAnalysis.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 250)
                            .overlay(
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.mint)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                
                VStack(alignment: .leading, spacing: 24) {
                    // Nutrition Score
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 0) {
                            Text("Nutrition Score: ")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("\(plateAnalysis.nutritionScore, specifier: "%.1f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("/10")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * (plateAnalysis.nutritionScore / 10), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text(plateAnalysis.analysisDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    // Macronutrients
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Macronutrients")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            MacronutrientCard(
                                title: "Protein",
                                value: "\(plateAnalysis.protein)g",
                                color: .green
                            )
                            
                            MacronutrientCard(
                                title: "Carbs",
                                value: "\(plateAnalysis.carbs)g",
                                color: .blue
                            )
                            
                            MacronutrientCard(
                                title: "Fat",
                                value: "\(plateAnalysis.fat)g",
                                color: .orange
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Calories")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(plateAnalysis.calories) kcal")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Ingredient Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ingredient Breakdown")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 0) {
                            ForEach(plateAnalysis.ingredients.indices, id: \.self) { index in
                                let ingredient = plateAnalysis.ingredients[index]
                                HStack {
                                    Text(ingredient.name)
                                        .font(.body)
                                    Spacer()
                                    Text(ingredient.amount)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 16)
                                
                                if index < plateAnalysis.ingredients.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(Color.clear)
                    }
                    
                    // Insights & Suggestions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Insights & Suggestions")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            ForEach(plateAnalysis.insights.indices, id: \.self) { index in
                                let insight = plateAnalysis.insights[index]
                                PlateInsightCard(insight: insight)
                            }
                        }
                    }
                    
                    // Feedback Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Is this analysis correct?")
                            .font(.title3)
                            .fontWeight(.bold)
                        
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
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(feedbackGiven ? Color.green : Color.gray.opacity(0.1))
                                .cornerRadius(25)
                            }
                            
                            Button(action: {
                                // Handle negative feedback
                            }) {
                                HStack {
                                    Image(systemName: "hand.thumbsdown")
                                    Text("No")
                                }
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(25)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
    }
}

struct MacronutrientCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
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

#Preview {
    PlateDetailView(plateAnalysis: PlateAnalysisHistory.mockData())
}
