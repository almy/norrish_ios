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
    let onLogMeal: ((MealLogIntent) -> Bool)?

    init(
        analysis: PlateAnalysis,
        image: UIImage?,
        onStartNewScan: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onLogMeal: ((MealLogIntent) -> Bool)? = nil
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
    @State private var showMealIntentSheet = false
    @State private var selectedMealIntent: MealLogIntent = .ateIt
    @State private var showLogFeedbackAlert = false
    @State private var logFeedbackTitle = ""
    @State private var logFeedbackMessage = ""
    @State private var dismissAfterLogFeedback = false
    
    private let primary = Color.momentumAmber
    private let nordicBackground = Color.nordicBone

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
            logMealIntentSheet
        }
        .alert(logFeedbackTitle, isPresented: $showLogFeedbackAlert) {
            Button("OK") {
                if dismissAfterLogFeedback {
                    onClose()
                    dismiss()
                }
            }
        } message: {
            Text(logFeedbackMessage)
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
                        .fill(Color.nordicBone.opacity(0.8))
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
                        .font(AppFonts.label)
                        .kerning(2.5)
                        .foregroundColor(primary)
                        .textCase(.uppercase)
                }
                Text(analysis.description)
                    .font(AppFonts.serif(32, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                let m = analysis.macronutrients
                Text("\(m.calories) kcal • \(Int(analysis.nutritionScore))/10")
                    .font(AppFonts.sans(12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(1.2)
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
                .font(AppFonts.label)
                .kerning(2.5)
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
                        .font(AppFonts.sans(16, weight: .regular))
                        .foregroundColor(.nordicSlate)
                    Text(NSLocalizedString("chef.insight", comment: "Chef's Insight"))
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(2)
                        .textCase(.uppercase)
                }
                Text("“\(overviewText)”")
                    .font(AppFonts.serif(17, weight: .regular))
                    .italic()
                    .foregroundColor(.midnightSpruce)
                    .lineSpacing(3)
                if let confidenceText {
                    Text(confidenceText)
                        .font(AppFonts.sans(11, weight: .semibold))
                        .foregroundColor(.nordicSlate)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if let uncertaintyNote {
                    Text("Uncertainty: \(uncertaintyNote)")
                        .font(AppFonts.sans(11, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
                if let topAssumption {
                    Text("Assumption: \(topAssumption)")
                        .font(AppFonts.sans(11, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(AppFonts.sans(16, weight: .regular))
                        .foregroundColor(.nordicSlate)
                    Text(NSLocalizedString("ingredients.detected", comment: "Detected Ingredients"))
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(2)
                        .textCase(.uppercase)
                }
                ChipFlow(alignment: .leading, spacing: 8) {
                    ForEach(analysis.ingredients.indices, id: \.self) { idx in
                        let ing = analysis.ingredients[idx]
                        Text(ing.name)
                            .font(AppFonts.sans(11, weight: .medium))
                            .foregroundColor(.nordicSlate)
                            .textCase(.uppercase)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 999)
                                    .fill(Color.cardSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 999)
                                            .stroke(Color.cardBorder, lineWidth: 1)
                                    )
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(NSLocalizedString("macro.profile", comment: "Macro Profile"))
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(3)
                        .textCase(.uppercase)
                    Spacer()
                    Text(NSLocalizedString("plate.optimized.badge", comment: "Optimized badge"))
                        .font(AppFonts.sans(9, weight: .bold))
                        .foregroundColor(primary)
                        .textCase(.uppercase)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                MacroBarRow(
                    title: NSLocalizedString("nutrition.protein", comment: "Protein"),
                    label: "\(analysis.macronutrients.protein)g • \(proteinLabel)",
                    fill: proteinFill,
                    accent: primary
                )
                MacroBarRow(
                    title: NSLocalizedString("nutrition.carbs", comment: "Carbohydrates"),
                    label: "\(analysis.macronutrients.carbs)g • \(carbsLabel)",
                    fill: carbsFill,
                    accent: primary
                )
                MacroBarRow(
                    title: NSLocalizedString("nutrition.fat", comment: "Dietary Fats"),
                    label: "\(analysis.macronutrients.fat)g • \(fatLabel)",
                    fill: fatFill,
                    accent: primary
                )
            }

            if let m = analysis.micronutrients {
                VStack(alignment: .leading, spacing: 12) {
                    Text("MICRONUTRIENTS")
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(2)
                    HStack(spacing: 10) {
                        PlateMicronutrientCard(name: "Fiber", level: "\(m.fiberG ?? 0) g", color: .mossInsight)
                        PlateMicronutrientCard(name: "Vitamin C", level: "\(m.vitaminCMg ?? 0) mg", color: .momentumAmber)
                        PlateMicronutrientCard(name: "Iron", level: "\(m.ironMg ?? 0) mg", color: .midnightSpruce)
                    }
                    if let other = m.other, !other.isEmpty {
                        Text(other)
                            .font(AppFonts.sans(11, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }
                }
            }

            if !analysis.insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(AppFonts.sans(16, weight: .regular))
                            .foregroundColor(.nordicSlate)
                        Text("Actionable Insights")
                            .font(AppFonts.label)
                            .foregroundColor(.nordicSlate)
                            .kerning(2)
                            .textCase(.uppercase)
                    }
                    ForEach(Array(analysis.insights.prefix(3).enumerated()), id: \.offset) { _, insight in
                        ResultModernInsightCard(insight: insight)
                    }
                }
            }

            // Temporarily hidden per product decision.
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
                        .font(AppFonts.sans(13, weight: .bold))
                        .kerning(2)
                        .textCase(.uppercase)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 360)
                .frame(height: 64)
                .background(Color.midnightSpruce)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 90)
        }
        .ignoresSafeArea(edges: .bottom)
    }

}

private extension PlateAnalysisResultView {
    var logMealIntentSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.nordicSlate.opacity(0.25))
                .frame(width: 46, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            VStack(spacing: 6) {
                Text("Log Product")
                    .font(AppFonts.sans(10, weight: .bold))
                    .foregroundColor(.nordicSlate)
                    .kerning(2)
                    .textCase(.uppercase)
                Text(analysis.description)
                    .font(AppFonts.serif(28, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 10) {
                Text("What did you do?")
                    .font(AppFonts.sans(11, weight: .bold))
                    .foregroundColor(.nordicSlate)
                    .kerning(1.4)
                    .textCase(.uppercase)

                ForEach(MealLogIntent.allCases) { intent in
                    mealIntentRow(intent: intent)
                }
            }
            .padding(.horizontal, 8)

            Button(action: {
                showMealIntentSheet = false
                guard let onLogMeal else {
                    dismissAfterLogFeedback = false
                    logFeedbackTitle = "Logging unavailable"
                    logFeedbackMessage = "This screen is read-only and cannot log meal intent."
                    showLogFeedbackAlert = true
                    return
                }
                let didLog = onLogMeal(selectedMealIntent)
                dismissAfterLogFeedback = didLog
                if didLog {
                    logFeedbackTitle = "Meal logged"
                    logFeedbackMessage = "Saved as: \(selectedMealIntent.shortBadge)."
                } else {
                    logFeedbackTitle = "Could not log meal"
                    logFeedbackMessage = "Please try again."
                }
                showLogFeedbackAlert = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Log Choice")
                        .font(AppFonts.sans(13, weight: .bold))
                        .kerning(1.6)
                        .textCase(.uppercase)
                }
                .foregroundColor(.nordicBone)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.midnightSpruce)
                .clipShape(Capsule())
                .shadow(color: Color.midnightSpruce.opacity(0.24), radius: 14, x: 0, y: 8)
            }
            .padding(.top, 26)
            .padding(.horizontal, 8)

            Button(action: { showMealIntentSheet = false }) {
                Text("Dismiss")
                    .font(AppFonts.sans(10, weight: .bold))
                    .foregroundColor(.nordicSlate)
                    .kerning(1.8)
                    .textCase(.uppercase)
            }
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white)
        )
        .presentationDetents([.height(590)])
        .presentationCornerRadius(34)
    }

    @ViewBuilder
    func mealIntentRow(intent: MealLogIntent) -> some View {
        Button(action: {
            selectedMealIntent = intent
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selectedMealIntent == intent ? Color.white : Color.white.opacity(0.85))
                        .frame(width: 46, height: 46)
                    Image(systemName: intent.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                }
                Text(intent.title)
                    .font(AppFonts.sans(14, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Spacer()
                if selectedMealIntent == intent {
                    Circle()
                        .fill(Color.midnightSpruce)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.nordicSlate.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(selectedMealIntent == intent ? Color.white : Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedMealIntent == intent ? Color.midnightSpruce : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension MealLogIntent {
    var systemImage: String {
        switch self {
        case .ateIt:
            return "fork.knife"
        case .boughtIt:
            return "cart"
        case .checkingInfo:
            return "eye"
        case .forSomeoneElse:
            return "person.2"
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
                .stroke(Color.nordicSlate.opacity(0.2), lineWidth: 16)
                .frame(width: 200, height: 200)
            Circle()
                .trim(from: 0, to: Swift.min(Swift.max(score/10.0, 0.0), 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", score))
                        .font(AppFonts.serif(34, weight: .bold))
                    Text("/10")
                        .font(AppFonts.sans(14, weight: .medium))
                        .foregroundColor(.nordicSlate)
                }
                Text(label)
                    .font(AppFonts.sans(12, weight: .semibold))
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
                Text(title)
                    .font(AppFonts.sans(12, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Spacer()
            }
            HStack {
                Text(value).font(AppFonts.serif(26, weight: .bold)).foregroundColor(.midnightSpruce)
                Spacer()
            }
        }
        .padding()
        .frame(minHeight: 96)
        .background(Color.cardSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
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
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(value)
                .font(AppFonts.sans(11, weight: .semibold))
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
                .foregroundColor(.midnightSpruce)

            Spacer()

            Text(amount)
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.cardSurface
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
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
                    .font(AppFonts.sans(15, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Text(insight.description)
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cardBorder, lineWidth: 1)
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
        case .positive: return .mossInsight
        case .suggestion: return .momentumAmber
        case .warning: return .midnightSpruce
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
                .font(AppFonts.sans(13, weight: .medium))
                .foregroundColor(.midnightSpruce)
            Text(level)
                .font(AppFonts.sans(11, weight: .regular))
                .foregroundColor(.nordicSlate)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
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
        if let first = analysis.insights.first {
            return first.description
        }
        let m = analysis.macronutrients
        return "Approx. P \(m.protein)g • C \(m.carbs)g • F \(m.fat)g • \(m.calories) kcal"
    }

    var proteinFill: CGFloat {
        CGFloat(max(0, min(1, proteinCalories / max(1, macroCaloriesTotal))))
    }

    var carbsFill: CGFloat {
        CGFloat(max(0, min(1, carbCalories / max(1, macroCaloriesTotal))))
    }

    var fatFill: CGFloat {
        CGFloat(max(0, min(1, fatCalories / max(1, macroCaloriesTotal))))
    }

    var proteinLabel: String {
        ratioLabel(proteinCalories / max(1, macroCaloriesTotal), kind: "protein")
    }

    var carbsLabel: String {
        ratioLabel(carbCalories / max(1, macroCaloriesTotal), kind: "carbs")
    }

    var fatLabel: String {
        ratioLabel(fatCalories / max(1, macroCaloriesTotal), kind: "fat")
    }

    var proteinCalories: Double { Double(analysis.macronutrients.protein * 4) }
    var carbCalories: Double { Double(analysis.macronutrients.carbs * 4) }
    var fatCalories: Double { Double(analysis.macronutrients.fat * 9) }
    var macroCaloriesTotal: Double { max(1.0, proteinCalories + carbCalories + fatCalories) }

    func ratioLabel(_ ratio: Double, kind: String) -> String {
        switch kind {
        case "protein":
            if ratio < 0.15 { return "Low" }
            if ratio <= 0.35 { return "Good" }
            return "High"
        case "carbs":
            if ratio < 0.35 { return "Low" }
            if ratio <= 0.55 { return "Moderate" }
            return "High"
        default:
            if ratio < 0.20 { return "Low" }
            if ratio <= 0.35 { return "Moderate" }
            return "High"
        }
    }

    var confidenceText: String? {
        guard let connections = analysis.connections else { return nil }
        guard let raw = connections.first(where: { $0.lowercased().hasPrefix("confidence_overall=") }) else { return nil }
        let value = raw.replacingOccurrences(of: "confidence_overall=", with: "")
        if let num = Double(value) {
            return "Confidence: \(Int((num * 100).rounded()))%"
        }
        return nil
    }

    var uncertaintyNote: String? {
        guard let connections = analysis.connections else { return nil }
        guard let raw = connections.first(where: { $0.lowercased().hasPrefix("uncertainty_note=") }) else { return nil }
        return raw.replacingOccurrences(of: "uncertainty_note=", with: "")
    }

    var topAssumption: String? {
        guard let connections = analysis.connections else { return nil }
        guard let raw = connections.first(where: { $0.lowercased().hasPrefix("top_assumption=") }) else { return nil }
        return raw.replacingOccurrences(of: "top_assumption=", with: "")
    }

    func saveFeedback(isCorrect: Bool) {
        guard !feedbackGiven else { return }
        feedbackGiven = true
        let defaults = UserDefaults.standard
        var usefulness = defaults.dictionary(forKey: "plateAnalysis.usefulnessByType") as? [String: Double] ?? [:]
        for insight in analysis.insights {
            let key = insight.type.rawValue.lowercased()
            let prev = usefulness[key] ?? 0.5
            let target = isCorrect ? 1.0 : 0.0
            usefulness[key] = (0.7 * prev) + (0.3 * target)
        }
        defaults.set(usefulness, forKey: "plateAnalysis.usefulnessByType")

        var followed = defaults.stringArray(forKey: "plateAnalysis.followedActions") ?? []
        if isCorrect {
            let titles = analysis.insights
                .filter { $0.type == .suggestion || $0.type == .positive }
                .map { $0.title }
            followed.append(contentsOf: titles)
            let deduped = Array(Set(followed))
            followed = Array(deduped.suffix(50))
        }
        defaults.set(Array(followed), forKey: "plateAnalysis.followedActions")
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
                    .font(AppFonts.label)
                    .foregroundColor(.nordicSlate)
                    .kerning(2)
                Spacer()
                Text(label)
                    .font(AppFonts.serif(18, weight: .regular))
                    .foregroundColor(.midnightSpruce)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.cardSurface)
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
