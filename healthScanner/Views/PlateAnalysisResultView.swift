//
//  PlateAnalysisResultView.swift
//  norrish
//
//  Created by myftiu on 09/09/25.
//

import SwiftUI
import UIKit

struct PlateAnalysisResultView: View {
    let analysis: PlateAnalysis
    let image: UIImage?
    let onStartNewScan: () -> Void
    let onClose: () -> Void
    let onLogMeal: (() -> Void)?  // Simplified to avoid external type dependency

    init(
        analysis: PlateAnalysis,
        image: UIImage?,
        onStartNewScan: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onLogMeal: (() -> Void)? = nil
    ) {
        self.analysis = analysis
        self.image = image
        self.onStartNewScan = onStartNewScan
        self.onClose = onClose
        self.onLogMeal = onLogMeal
    }

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackGiven = false
    @State private var showNutriInfo = false
    @State private var showMealIntentSheet = false  // NEW
    
    private let primary = Color(red: 19 / 255, green: 182 / 255, blue: 236 / 255)
    private let nordicBackground = Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255)

    var body: some View {
        ZStack(alignment: .top) {
            nordicBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroHeader
                        contentCard
                    }
                    .frame(width: proxy.size.width, alignment: .top)
                    .padding(.bottom, 150)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }

            headerBar

            bottomCTA
        }
        .sheet(isPresented: $showMealIntentSheet) {
            VStack(spacing: 16) {
                Text("Log Your Meal")
                    .font(.headline)
                Text("Confirm logging this meal to your history.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button(action: {
                    showMealIntentSheet = false
                    onLogMeal?()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Log Choice")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(14)
                }
                Button("Cancel") {
                    showMealIntentSheet = false
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    private var heroHeader: some View {
        ZStack {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(primary)
                        )
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.5)
            .clipped()

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.0)]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: UIScreen.main.bounds.height * 0.5)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(primary)
                        .frame(width: 32, height: 1)
                    Text(NSLocalizedString("plate.optimized", comment: "Nutritionally Optimized label"))
                        .font(.system(size: 10, weight: .bold))
                        .kerning(3)
                        .foregroundColor(primary)
                        .textCase(.uppercase)
                }
                Text(analysis.description)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
                let m = analysis.macronutrients
                Text("\(m.calories) kcal • \(Int(analysis.nutritionScore))/10")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(1.4)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .frame(height: UIScreen.main.bounds.height * 0.5, alignment: .bottom)
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: { onClose(); dismiss() }) {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    )
            }
            Spacer()
            Text(NSLocalizedString("plate.visual_insight", comment: "Visual Insight title"))
                .font(.system(size: 10, weight: .bold))
                .kerning(3)
                .foregroundColor(.white.opacity(0.9))
                .textCase(.uppercase)
            Spacer()
            Button(action: { onClose(); dismiss() }) {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "menucard")
                        .font(.system(size: 16))
                        .foregroundColor(.primary.opacity(0.4))
                    Text(NSLocalizedString("chef.insight", comment: "Chef's Insight"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary.opacity(0.4))
                        .kerning(2)
                        .textCase(.uppercase)
                }
                Text("“\(overviewText)”")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(Color(.label))
                    .lineSpacing(6)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 16))
                        .foregroundColor(.primary.opacity(0.4))
                    Text(NSLocalizedString("ingredients.detected", comment: "Detected Ingredients"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary.opacity(0.4))
                        .kerning(2)
                        .textCase(.uppercase)
                }
                ChipFlow(alignment: .leading, spacing: 8) {
                    ForEach(analysis.ingredients.indices, id: \.self) { idx in
                        let ing = analysis.ingredients[idx]
                        Text(ing.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(.systemGray))
                            .textCase(.uppercase)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 999)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 999)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(NSLocalizedString("macro.profile", comment: "Macro Profile"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .kerning(3)
                        .textCase(.uppercase)
                    Spacer()
                    Text(NSLocalizedString("plate.optimized.badge", comment: "Optimized badge"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(primary)
                        .textCase(.uppercase)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
 
                MacroBarRow(title: NSLocalizedString("nutrition.protein", comment: "Protein"), label: NSLocalizedString("macro.good", comment: "Good"), fill: 0.7, accent: primary)
                MacroBarRow(title: NSLocalizedString("nutrition.carbs", comment: "Carbohydrates"), label: NSLocalizedString("macro.moderate", comment: "Moderate"), fill: 0.5, accent: primary)
                MacroBarRow(title: NSLocalizedString("nutrition.fat", comment: "Dietary Fats"), label: NSLocalizedString("macro.minimal", comment: "Minimal"), fill: 0.25, accent: primary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 40)
        .background(
            nordicBackground
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.clear, lineWidth: 0)
                )
        )
        .offset(y: -28)
    }

    private var bottomCTA: some View {
        VStack {
            Spacer()
            Button(action: {
                showMealIntentSheet = true
            }) {
                HStack(spacing: 10) {
                    Text(NSLocalizedString("plate.log_meal", comment: "Log This Meal"))
                        .font(.system(size: 13, weight: .bold))
                        .kerning(2)
                        .textCase(.uppercase)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 360)
                .frame(height: 64)
                .background(Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 90)
        }
        .ignoresSafeArea(edges: .bottom)
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
                .trim(from: 0, to: Swift.min(Swift.max(score/10.0, 0.0), 1.0))
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(insight.description)
                    .font(.system(size: 13))
                    .foregroundColor(.primary.opacity(0.6))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                )
        )
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
        case .positive: return .green
        case .suggestion: return .orange
        case .warning: return .red
        }
    }
}

struct PlateMicronutrientCard: View {
    let name: String
    let level: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            Text(level)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.6))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
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

struct MacroBarRow: View {
    let title: String
    let label: String
    let fill: CGFloat // 0..1 visual fill to mirror mock
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .kerning(2)
                Spacer()
                Text(label)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundColor(Color(.label))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray6))
                        .frame(height: 2)
                    Capsule()
                        .fill(accent.opacity(0.3))
                        .frame(width: proxy.size.width * fill, height: 2)
                }
            }
            .frame(height: 2)
        }
    }
}

// Minimal flow layout for wrapping chips
struct ChipFlow<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlowLayoutContainer(spacing: spacing) {
            content()
        }
    }
}

private struct FlowLayoutContainer: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? CGFloat.infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = Swift.max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = Swift.max(rowHeight, size.height)
        }
    }
}

#Preview {
    PlateAnalysisResultView(analysis: PlateAnalysis.mockAnalysis(), image: nil, onStartNewScan: {}, onClose: {})
}

