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
    @State private var showMealIntentSheet = false
    @State private var showDetailsPanel = false
    @State private var selectedMealIntent: MealLogIntent = .ateIt
    @State private var showLogFeedbackAlert = false
    @State private var logFeedbackTitle = ""
    @State private var logFeedbackMessage = ""
    @State private var dismissAfterLogFeedback = false
    
    private let primary = Color.momentumAmber
    private let nordicBackground = Color.nordicBone
    private let scoreLow = Color.momentumAmber
    private let scoreGood = Color.mossInsight
    private let scorePoor = Color.red.opacity(0.85)

    var body: some View {
        ZStack(alignment: .bottom) {
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
            }

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
        let heroHeight = UIScreen.main.bounds.height * 0.5
        return ZStack {
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
            .frame(height: heroHeight)
            .clipped()

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.1), Color.black.opacity(0.0)]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: heroHeight)

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(scoreBandColor)
                            .frame(width: 32, height: 1)
                        Text(scoreBandTitle.uppercased())
                            .font(AppFonts.label)
                            .kerning(2.2)
                            .foregroundColor(scoreBandColor)
                    }
                    Text(analysis.description)
                        .font(AppFonts.serif(34, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text(heroMetaLine)
                        .font(AppFonts.sans(11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .kerning(1.0)
                        .textCase(.uppercase)
                }

                MiniScoreRing(
                    score: analysis.nutritionScore,
                    color: scoreBandColor
                )
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .frame(height: heroHeight, alignment: .bottom)
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
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 10) {
                Circle()
                    .fill(scoreBandColor)
                    .frame(width: 6, height: 6)
                Text(confidenceLabel.uppercased())
                    .font(AppFonts.sans(10, weight: .bold))
                    .kerning(1.8)
                    .foregroundColor(.nordicSlate)
                Capsule()
                    .fill(Color.cardBorder)
                    .frame(height: 2)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(scoreBandColor)
                                .frame(width: proxy.size.width * confidenceClamped, height: 2)
                        }
                    }
                Text("\(Int((confidenceClamped * 100).rounded()))%")
                    .font(AppFonts.sans(10, weight: .bold))
                    .foregroundColor(.nordicSlate.opacity(0.6))
            }

            if !scoreRationaleLines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(icon: "chart.line.uptrend.xyaxis", title: "Why this score")
                    ForEach(scoreRationaleLines.indices, id: \.self) { idx in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(scoreBandColor)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(scoreRationaleLines[idx])
                                .font(AppFonts.sans(13, weight: .regular))
                                .foregroundColor(.nordicSlate)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let primaryQuickWin {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "fork.knife", title: "Next time, try")
                    Text("\"\(primaryQuickWin)\"")
                        .font(AppFonts.serif(26, weight: .regular))
                        .italic()
                        .foregroundColor(.midnightSpruce)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Macro Profile")
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(3)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(analysis.macronutrients.calories) kcal")
                        .font(AppFonts.sans(10, weight: .bold))
                        .foregroundColor(scoreBandColor)
                        .textCase(.uppercase)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(scoreBandColor.opacity(0.14))
                        .clipShape(Capsule())
                }

                PlateMacroProgressRow(
                    title: "Protein",
                    amount: analysis.macronutrients.protein,
                    dailyTarget: 50,
                    color: scorePoor
                )
                PlateMacroProgressRow(
                    title: "Carbohydrates",
                    amount: analysis.macronutrients.carbs,
                    dailyTarget: 275,
                    color: scoreLow
                )
                PlateMacroProgressRow(
                    title: "Fat",
                    amount: analysis.macronutrients.fat,
                    dailyTarget: 78,
                    color: primary.opacity(0.7)
                )
            }

            if !microHighlights.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: min(4, microHighlights.count)), spacing: 0) {
                    ForEach(microHighlights.indices, id: \.self) { idx in
                        let item = microHighlights[idx]
                        VStack(spacing: 4) {
                            Text(item.valueText)
                                .font(AppFonts.sans(16, weight: .semibold))
                                .foregroundColor(item.color)
                            Text(item.name)
                                .font(AppFonts.sans(10, weight: .medium))
                                .foregroundColor(.nordicSlate)
                                .lineLimit(1)
                            if let dv = item.dailyValueText {
                                Text(dv)
                                    .font(AppFonts.sans(9, weight: .semibold))
                                    .foregroundColor(item.color.opacity(0.9))
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) {
                            if idx < microHighlights.count - 1 {
                                Rectangle().fill(Color.cardBorder).frame(width: 1)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
            }

            if !secondaryQuickWins.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "lightbulb.max", title: "More ideas")
                    ForEach(secondaryQuickWins.indices, id: \.self) { idx in
                        let tip = secondaryQuickWins[idx]
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(primary.opacity(0.14))
                                    .frame(width: 24, height: 24)
                                Text("\(idx + 2)")
                                    .font(AppFonts.sans(11, weight: .bold))
                                    .foregroundColor(primary)
                            }
                            Text(tip)
                                .font(AppFonts.sans(13, weight: .medium))
                                .foregroundColor(.midnightSpruce)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        if idx < secondaryQuickWins.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showDetailsPanel.toggle() } }) {
                    HStack {
                        Text("Details & Ingredients")
                            .font(AppFonts.sans(11, weight: .bold))
                            .kerning(1.6)
                            .textCase(.uppercase)
                            .foregroundColor(.nordicSlate)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.nordicSlate.opacity(0.7))
                            .rotationEffect(.degrees(showDetailsPanel ? 180 : 0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if showDetailsPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        if !analysis.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Likely ingredients")
                                    .font(AppFonts.sans(9, weight: .bold))
                                    .kerning(1.4)
                                    .textCase(.uppercase)
                                    .foregroundColor(.nordicSlate.opacity(0.6))
                                ChipFlow(alignment: .leading, spacing: 8) {
                                    ForEach(analysis.ingredients.indices, id: \.self) { idx in
                                        Text(analysis.ingredients[idx].name)
                                            .font(AppFonts.sans(11, weight: .medium))
                                            .foregroundColor(.nordicSlate)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(Color.cardSurface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        if let connectionsNote {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(scoreLow)
                                Text(connectionsNote)
                                    .font(AppFonts.sans(11, weight: .medium))
                                    .foregroundColor(scoreLow)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(scoreLow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Insights")
                                .font(AppFonts.sans(9, weight: .bold))
                                .kerning(1.4)
                                .textCase(.uppercase)
                                .foregroundColor(.nordicSlate.opacity(0.6))
                            ForEach(insightsForDetails.indices, id: \.self) { idx in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: insightsForDetails[idx].icon)
                                        .font(.system(size: 13))
                                        .foregroundColor(.nordicSlate.opacity(0.6))
                                        .padding(.top, 1)
                                    Text(insightsForDetails[idx].text)
                                        .font(AppFonts.sans(11, weight: .regular))
                                        .foregroundColor(.nordicSlate)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        Text("Estimates are based on visual analysis and can vary with image angle, lighting, and portion context.")
                            .font(AppFonts.sans(11, weight: .regular))
                            .foregroundColor(.nordicSlate.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .background(Color.white.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 40)
        .background(
            nordicBackground
                .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
        )
        .offset(y: -28)
    }

    @ViewBuilder
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.nordicSlate.opacity(0.6))
            Text(title)
                .font(AppFonts.sans(10, weight: .bold))
                .foregroundColor(.nordicSlate.opacity(0.7))
                .kerning(1.9)
                .textCase(.uppercase)
        }
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
private struct MiniScoreRing: View {
    let score: Double
    let color: Color

    private var clampedScore: Double {
        max(0.0, min(10.0, score))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 72, height: 72)
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 4)
                .frame(width: 62, height: 62)
            Circle()
                .trim(from: 0, to: clampedScore / 10.0)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 62, height: 62)
            VStack(spacing: 0) {
                Text("\(Int(clampedScore.rounded()))")
                    .font(AppFonts.serif(22, weight: .semibold))
                    .foregroundColor(.white)
                Text("/10")
                    .font(AppFonts.sans(9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
}

private struct PlateMacroProgressRow: View {
    let title: String
    let amount: Int
    let dailyTarget: Int
    let color: Color

    private var percent: Int {
        Int((Double(amount) / Double(max(1, dailyTarget)) * 100).rounded())
    }

    private var fillRatio: Double {
        min(1.0, max(0.0, Double(amount) / Double(max(1, dailyTarget))))
    }

    private var balanceLabel: String {
        switch percent {
        case ..<10: return "Low"
        case ..<25: return "Moderate"
        default: return "Higher"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text(title.uppercased())
                        .font(AppFonts.sans(11, weight: .bold))
                        .foregroundColor(.nordicSlate)
                        .kerning(1.2)
                    Text(balanceLabel)
                        .font(AppFonts.sans(10, weight: .semibold))
                        .foregroundColor(color)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(color.opacity(0.14))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("\(amount)g")
                    .font(AppFonts.sans(14, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Text("/ \(dailyTarget)g")
                    .font(AppFonts.sans(10, weight: .medium))
                    .foregroundColor(.nordicSlate.opacity(0.7))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.cardSurface)
                        .frame(height: 4)
                    Capsule()
                        .fill(color.opacity(0.4))
                        .frame(width: proxy.size.width * fillRatio, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(percent)% of daily target")
                .font(AppFonts.sans(9, weight: .medium))
                .foregroundColor(.nordicSlate.opacity(0.6))
        }
    }
}

private struct PlateMicroHighlight {
    let name: String
    let valueText: String
    let dailyValueText: String?
    let color: Color
}

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
    var scoreBandTitle: String {
        switch analysis.nutritionScore {
        case ..<4.5: return "Needs Attention"
        case ..<7.0: return "Room to Improve"
        default: return "Well Balanced"
        }
    }

    var scoreBandColor: Color {
        switch analysis.nutritionScore {
        case ..<4.5: return scorePoor
        case ..<7.0: return scoreLow
        default: return scoreGood
        }
    }

    var heroMetaLine: String {
        var segments: [String] = []
        if let mealType = analysis.mealType?.trimmingCharacters(in: .whitespacesAndNewlines), !mealType.isEmpty {
            segments.append(mealType.capitalized)
        }
        if let portion = analysis.portionEstimate {
            segments.append("~\(Int(portion.amount.rounded())) \(portion.unit)")
        }
        segments.append("\(analysis.macronutrients.calories) kcal")
        return segments.joined(separator: " • ")
    }

    var confidenceRaw: Double {
        if let confidence = analysis.confidenceOverall {
            return confidence
        }
        guard let connections = analysis.connections else { return 0.6 }
        guard let raw = connections.first(where: { $0.lowercased().hasPrefix("confidence_overall=") }) else { return 0.6 }
        let value = raw.replacingOccurrences(of: "confidence_overall=", with: "")
        return Double(value) ?? 0.6
    }

    var confidenceClamped: Double {
        max(0.0, min(1.0, confidenceRaw))
    }

    var confidenceLabel: String {
        switch confidenceClamped {
        case 0.75...: return "High confidence"
        case 0.5...: return "Moderate confidence"
        default: return "Low confidence"
        }
    }

    var scoreRationaleLines: [String] {
        if let why = analysis.whyThisScore?.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), !why.isEmpty {
            return Array(why.prefix(3))
        }
        let fallback = analysis.insights.prefix(2).map(\.description).filter { !$0.isEmpty }
        return fallback.isEmpty ? ["Macronutrient balance and estimated portion drove this score."] : fallback
    }

    var primaryQuickWin: String? {
        if let wins = analysis.quickWinActions?.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), !wins.isEmpty {
            return wins[0]
        }
        return analysis.insights.first(where: { $0.type == .suggestion })?.description
    }

    var secondaryQuickWins: [String] {
        if let wins = analysis.quickWinActions?.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }), wins.count > 1 {
            return Array(wins.dropFirst().prefix(3))
        }
        return Array(analysis.insights.filter { $0.type == .suggestion }.map(\.description).prefix(2))
    }

    var microHighlights: [PlateMicroHighlight] {
        if let notable = analysis.micronutrients?.notable, !notable.isEmpty {
            return Array(notable.prefix(4)).map { item in
                let color: Color = {
                    switch item.direction?.lowercased() {
                    case "low", "down":
                        return scorePoor
                    case "high", "up":
                        return scoreLow
                    default:
                        return .midnightSpruce
                    }
                }()
                return PlateMicroHighlight(
                    name: item.name,
                    valueText: formatAmount(item.amount, unit: item.unit),
                    dailyValueText: item.dailyValuePct.map { "\($0)% DV" },
                    color: color
                )
            }
        }

        guard let micros = analysis.micronutrients else { return [] }
        var rows: [PlateMicroHighlight] = []
        if let fiber = micros.fiberG {
            rows.append(PlateMicroHighlight(name: "Fiber", valueText: "\(fiber)g", dailyValueText: nil, color: scorePoor))
        }
        if let vitC = micros.vitaminCMg {
            rows.append(PlateMicroHighlight(name: "Vitamin C", valueText: "\(vitC)mg", dailyValueText: nil, color: scoreGood))
        }
        if let iron = micros.ironMg {
            rows.append(PlateMicroHighlight(name: "Iron", valueText: "\(iron)mg", dailyValueText: nil, color: .midnightSpruce))
        }
        return Array(rows.prefix(4))
    }

    var connectionsNote: String? {
        if let extracted = analysis.connections?.first(where: {
            let lower = $0.lowercased()
            return lower.contains("allergen") || lower.contains("contains ") || lower.contains("gluten")
        }) {
            return extracted
        }
        return nil
    }

    var insightsForDetails: [(icon: String, text: String)] {
        var details: [(icon: String, text: String)] = []
        if let note = analysis.uncertaintyNotes?.first(where: { !$0.isEmpty }) ?? uncertaintyNoteFromConnections {
            details.append(("eye", note))
        }
        if let assumption = analysis.topAssumptions?.first(where: { !$0.isEmpty }) ?? topAssumptionFromConnections {
            details.append(("ruler", assumption))
        }
        if let summary = analysis.micronutrients?.summary, !summary.isEmpty {
            details.append(("text.alignleft", summary))
        }
        if details.isEmpty {
            details.append(("info.circle", "No additional assumptions were provided for this analysis."))
        }
        return Array(details.prefix(3))
    }

    var uncertaintyNoteFromConnections: String? {
        guard let connections = analysis.connections else { return nil }
        guard let raw = connections.first(where: { $0.lowercased().hasPrefix("uncertainty_note=") }) else { return nil }
        return raw.replacingOccurrences(of: "uncertainty_note=", with: "")
    }

    var topAssumptionFromConnections: String? {
        guard let connections = analysis.connections else { return nil }
        guard let raw = connections.first(where: { $0.lowercased().hasPrefix("top_assumption=") }) else { return nil }
        return raw.replacingOccurrences(of: "top_assumption=", with: "")
    }

    func formatAmount(_ value: Double, unit: String) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return "\(Int(value.rounded()))\(unit)"
        }
        return "\(String(format: "%.1f", value))\(unit)"
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
