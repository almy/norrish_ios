/*
 ADR-0001 Summary: Multi-horizon insight strategy with short-window regression and snapshot fallback.
 
 Context:
 - We want responsive, privacy-preserving recommendations that adapt quickly to recent behavior (short window),
   while still offering continuity when history is wiped or temporarily insufficient.
 
 Decision:
 - Use a short rolling window (e.g., 14–30 days) for on-device linear regression that targets next-day plate scores.
 - Persist a lightweight snapshot (featureNames + coefficients) after fitting, to warm-start future sessions.
 - When insufficient recent data is available, fall back to the saved snapshot to generate correlation-style recommendations.
 - Keep rule-based insights and correlation discovery composable alongside ML-driven recommendations.
 
 Consequences:
 - Training remains fast and bounded by the recent window.
 - Users still see personalized insights even after a history reset.
 - Snapshot is small, and does not contain raw user data.
 
 See also: docs/adr/0001-insights-strategy-and-ml-snapshot.md
*/
import Foundation
import SwiftData

// MARK: - On-Device Nutrition Recommendation Engine

@MainActor
final class OnDeviceNutritionRecommendationEngine: ObservableObject {

    // MARK: - Shared Formatters

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // MARK: - Constants

    private struct NutritionConstants {
        // Privacy
        static let privacyBudget: Double = 2.0

        // Time windows
        static let plateWindowDays = 14
        static let productWindowDays = 21

        /// Legacy static nutrient targets; deprecated in favor of adaptive baselines and trends.
        /// Kept for backward compatibility with deficiency-based recommendations.
        static let nutritionTargets: [NutrientDeficiency.Nutrient: Double] = [
            .fiber: 25,         // g
            .protein: 60,       // g
            .vitaminC: 75,      // mg
            .iron: 8           // mg
        ]

        struct Adaptive {
            private static let dayFormatter: DateFormatter = {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                return df
            }()

            /// Computes a rolling average over `days` from provided daily values.
            static func rollingAverage(valuesByDay: [String: Double], days: Int, now: Date = Date()) -> Double {
                let df = Self.dayFormatter
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
                let filtered = valuesByDay.compactMap { (k, v) -> (Date, Double)? in
                    guard let d = df.date(from: k) else { return nil }
                    return d >= cutoff ? (d, v) : nil
                }
                let values = filtered.map { $0.1 }.filter { $0.isFinite }
                guard !values.isEmpty else { return 0 }
                return values.reduce(0, +) / Double(values.count)
            }

            /// Returns (recent, baseline, deltaPct) for a given nutrient timeline using recentDays and baselineDays windows.
            static func trend(valuesByDay: [String: Double], recentDays: Int, baselineDays: Int, now: Date = Date()) -> (recent: Double, baseline: Double, deltaPct: Double) {
                let recent = rollingAverage(valuesByDay: valuesByDay, days: recentDays, now: now)
                let baseline = rollingAverage(valuesByDay: valuesByDay, days: baselineDays, now: now)
                let deltaPct = baseline > 0 ? ((recent - baseline) / baseline) * 100 : 0
                return (recent, baseline, deltaPct)
            }
        }

        // Deficiency thresholds
        static let deficiencyThreshold: Double = 0.8 // 20% below target

        // Product thresholds
        static let highSugarThreshold: Double = 20  // g
        static let highSodiumThreshold: Double = 1.5 // g
        static let veryHighSodiumThreshold: Double = 2.0 // g

        // Plate score thresholds
        static let lowFiberPlateThreshold: Double = 10 // g
        static let meaningfulScoreDifference: Double = 0.5

        // Recommendation thresholds
        static let minHighSugarProductCount = 3
        static let minHighSodiumProductCount = 2
        static let minLowFiberPlateCount = 2
        static let minCategoryCount = 3
        static let categoryDominanceThreshold: Double = 0.4
        static let substitutionMinCategoryCount = 2
        static let substitutionMaxRecs = 3
        static let substitutionSugarDeltaG: Double = 5.0
        static let substitutionSodiumDeltaG: Double = 0.3
        static let substitutionFatDeltaG: Double = 3.0

        // ML thresholds
        static let minTrainingDataSize = 5
        static let mlRegularization: Double = 0.8
        static let mlWeightThreshold: Double = 0.01

        // Relevance scores
        static let baseRelevanceScore: Double = 0.6
        static let fiberRelevanceBase: Double = 0.8
        static let proteinRelevanceBase: Double = 0.75
        static let vitaminCRelevanceBase: Double = 0.7
        static let micronutrientRelevanceBase: Double = 0.6
        static let sugarSwapRelevance: Double = 0.78
        static let sodiumRiskRelevance: Double = 0.7
        static let fiberPairingRelevance: Double = 0.72
        static let allergenRelevance: Double = 0.85
    }

    private let privacyBudget = NutritionConstants.privacyBudget
    private let plateWindowDays = NutritionConstants.plateWindowDays
    private let productWindowDays = NutritionConstants.productWindowDays

    @Published var currentRecommendations: [NutritionRecommendation] = []
    @Published var currentCorrelations: [CorrelationInsight] = []

    init() {}

    /// Generates a ranked list of recommendations using a short-window ML model when possible,
    /// falling back to a previously saved snapshot if recent data is insufficient.
    /// Also intended to compose rule-based and correlation insights alongside ML.
    func generateRecommendations(plates: [PlateAnalysisHistory], products: [Product], preferences: DietaryPreferencesManager = .shared) async -> [NutritionRecommendation] {
        let recentPlates = filterRecent(items: plates, days: plateWindowDays, date: { $0.analyzedDate })
        let recentProducts = filterRecent(items: products, days: productWindowDays, date: { $0.scannedDate })

        // Attempt to build training data; if unavailable, try snapshot warm-start
        let trainingData = LocalRecommendationML.buildTrainingData(plates: recentPlates, products: recentProducts)
        var recs: [NutritionRecommendation] = []

        if let data = trainingData, data.X.count >= NutritionConstants.minTrainingDataSize {
            let mlRecs = generateMLRecommendations(training: data)
            recs += mlRecs
        } else if let snap = LocalRecommendationML.loadSnapshot() {
            // Use snapshot coefficients to generate static correlation-style recommendations
            let pairs = Array(zip(snap.featureNames, snap.coefficients))
            let nonIntercept = pairs.filter { $0.0 != "intercept" }
            let mostNegative = nonIntercept.sorted { $0.1 < $1.1 }.prefix(3)
            let mostPositive = nonIntercept.sorted { $0.1 > $1.1 }.prefix(3)

            for (name, weight) in mostNegative {
                guard weight < -NutritionConstants.mlWeightThreshold else { continue }
                recs.append(NutritionRecommendation(
                    title: friendlyTitle(for: name, positive: false),
                    message: "Learned previously: reducing this factor may improve next-day plate scores.",
                    reason: "Warm-start from saved model",
                    relevanceScore: min(1.0, NutritionConstants.baseRelevanceScore + min(0.4, abs(weight))),
                    type: .correlationInsight,
                    tags: [name],
                    evidence: [String(format: "Coefficient: %.3f (negative)", weight)]
                ))
            }
            for (name, weight) in mostPositive {
                guard weight > NutritionConstants.mlWeightThreshold else { continue }
                recs.append(NutritionRecommendation(
                    title: friendlyTitle(for: name, positive: true),
                    message: "Learned previously: leaning into this factor may help next-day plate scores.",
                    reason: "Warm-start from saved model",
                    relevanceScore: min(1.0, NutritionConstants.baseRelevanceScore + min(0.4, abs(weight))),
                    type: .correlationInsight,
                    tags: [name],
                    evidence: [String(format: "Coefficient: %.3f (positive)", weight)]
                ))
            }
        } else {
            recs.append(NutritionRecommendation(
                title: "Keep Building Your Model",
                message: "Scan a few more days of products and plates to train personalized insights.",
                reason: "Not enough history for an on-device model yet",
                relevanceScore: NutritionConstants.baseRelevanceScore,
                type: .habitPattern,
                tags: ["cold_start"],
                evidence: []
            ))
        }

        // Add adaptive, non-target-based trend insights
        let trendRecs = generateAdaptiveTrendInsights(plates: recentPlates, products: recentProducts)
        recs.append(contentsOf: trendRecs)

        // Also include correlation discoveries mapped to recommendations
        let correlations = discoverCorrelations(plates: recentPlates, products: recentProducts)
        recs.append(contentsOf: mapCorrelationsToRecommendations(correlations))

        let privatized = applyDifferentialPrivacy(recs)
        let sorted = privatized.sorted { $0.relevanceScore > $1.relevanceScore }

        currentRecommendations = sorted
        currentCorrelations = []
        return sorted
    }

    // MARK: - Filtering Helpers

    private func filterRecent<T>(items: [T], days: Int, date: (T) -> Date) -> [T] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return items.filter { date($0) >= cutoff }
    }

    // MARK: - Deficiency Analysis

    private func analyzeDeficiencies(recentPlates: [PlateAnalysisHistory], recentProducts: [Product]) -> [NutrientDeficiency] {
        let nutritionData = aggregateNutritionData(plates: recentPlates, products: recentProducts)
        let avgValues = calculateAverageNutrients(from: nutritionData)

        return NutrientDeficiency.Nutrient.allCases.compactMap { nutrient in
            createDeficiencyIfNeeded(for: nutrient, avgValue: avgValues[nutrient] ?? 0,
                                   plates: recentPlates, products: recentProducts)
        }
    }

    private struct DailyNutrition {
        var protein: Double = 0
        var fiber: Double = 0
        var vitaminC: Double = 0
        var iron: Double = 0
    }

    private func aggregateNutritionData(plates: [PlateAnalysisHistory], products: [Product]) -> [String: DailyNutrition] {
        var days: [String: DailyNutrition] = [:]
        let df = Self.dayFormatter

        for plate in plates {
            let day = df.string(from: plate.analyzedDate)
            var entry = days[day] ?? DailyNutrition()
            entry.protein += Double(plate.protein)

            if let micro = plate.micronutrients {
                entry.fiber += Double(micro.fiberG ?? 0)
                entry.vitaminC += Double(micro.vitaminCMg ?? 0)
                entry.iron += Double(micro.ironMg ?? 0)
            }
            days[day] = entry
        }

        for product in products {
            let day = df.string(from: product.scannedDate)
            var entry = days[day] ?? DailyNutrition()
            entry.protein += product.nutritionData.protein
            entry.fiber += product.nutritionData.fiber
            days[day] = entry
        }

        return days
    }

    private func calculateAverageNutrients(from days: [String: DailyNutrition]) -> [NutrientDeficiency.Nutrient: Double] {
        let dayCount = max(days.count, 1)
        let values = days.values

        return [
            .protein: values.map { $0.protein }.reduce(0, +) / Double(dayCount),
            .fiber: values.map { $0.fiber }.reduce(0, +) / Double(dayCount),
            .vitaminC: values.map { $0.vitaminC }.reduce(0, +) / Double(dayCount),
            .iron: values.map { $0.iron }.reduce(0, +) / Double(dayCount)
        ]
    }

    private func calculateDailyNutrientTimelines(plates: [PlateAnalysisHistory], products: [Product]) -> [NutrientDeficiency.Nutrient: [String: Double]] {
        var proteinByDay: [String: Double] = [:]
        var fiberByDay: [String: Double] = [:]
        var vitaminCByDay: [String: Double] = [:]
        var ironByDay: [String: Double] = [:]
        let df = Self.dayFormatter

        for plate in plates {
            let day = df.string(from: plate.analyzedDate)
            proteinByDay[day, default: 0] += Double(plate.protein)
            if let micro = plate.micronutrients {
                fiberByDay[day, default: 0] += Double(micro.fiberG ?? 0)
                vitaminCByDay[day, default: 0] += Double(micro.vitaminCMg ?? 0)
                ironByDay[day, default: 0] += Double(micro.ironMg ?? 0)
            }
        }

        for product in products {
            let day = df.string(from: product.scannedDate)
            proteinByDay[day, default: 0] += product.nutritionData.protein
            fiberByDay[day, default: 0] += product.nutritionData.fiber
        }

        return [
            .protein: proteinByDay,
            .fiber: fiberByDay,
            .vitaminC: vitaminCByDay,
            .iron: ironByDay
        ]
    }

    private func createDeficiencyIfNeeded(for nutrient: NutrientDeficiency.Nutrient, avgValue: Double,
                                        plates: [PlateAnalysisHistory], products: [Product]) -> NutrientDeficiency? {
        guard let target = NutritionConstants.nutritionTargets[nutrient], target > 0 else { return nil }
        guard avgValue < NutritionConstants.deficiencyThreshold * target else { return nil }

        let deficit = min(1.0, max(0.0, (target - avgValue) / target))
        let samples = generateSampleEvidence(for: nutrient, plates: plates, products: products)

        return NutrientDeficiency(
            nutrient: nutrient,
            deficitMagnitude: deficit,
            evidenceCount: max(plates.count, products.count),
            avgValue: avgValue,
            targetValue: target,
            windowDays: plateWindowDays,
            samplePlates: samples.plates,
            sampleProducts: samples.products
        )
    }

    private func generateSampleEvidence(for nutrient: NutrientDeficiency.Nutrient,
                                      plates: [PlateAnalysisHistory],
                                      products: [Product]) -> (plates: [SampleRef], products: [SampleRef]) {
        let df = Self.dayFormatter
        var plateSamples: [SampleRef] = []
        var productSamples: [SampleRef] = []

        switch nutrient {
        case .fiber:
            let lowFiberPlates = plates
                .map { ($0, Double($0.micronutrients?.fiberG ?? 0)) }
                .sorted { $0.1 < $1.1 }
                .prefix(2)

            for (plate, value) in lowFiberPlates {
                plateSamples.append(createPlateSample(plate: plate, metric: "fiber", value: "\(Int(value)) g", df: df))
            }

            let lowFiberProducts = products
                .sorted { $0.nutritionData.fiber < $1.nutritionData.fiber }
                .prefix(2)

            for product in lowFiberProducts {
                productSamples.append(createProductSample(product: product, metric: "fiber",
                                                        value: "\(String(format: "%.1f", product.nutritionData.fiber)) g", df: df))
            }

        case .protein:
            let lowProteinPlates = plates
                .sorted { $0.protein < $1.protein }
                .prefix(2)

            for plate in lowProteinPlates {
                plateSamples.append(createPlateSample(plate: plate, metric: "protein", value: "\(plate.protein) g", df: df))
            }

        case .vitaminC:
            let lowVitCPlates = plates
                .map { ($0, Double($0.micronutrients?.vitaminCMg ?? 0)) }
                .sorted { $0.1 < $1.1 }
                .prefix(2)

            for (plate, value) in lowVitCPlates {
                plateSamples.append(createPlateSample(plate: plate, metric: "vitamin C", value: "\(Int(value)) mg", df: df))
            }

        case .iron:
            let lowIronPlates = plates
                .map { ($0, Double($0.micronutrients?.ironMg ?? 0)) }
                .sorted { $0.1 < $1.1 }
                .prefix(2)

            for (plate, value) in lowIronPlates {
                plateSamples.append(createPlateSample(plate: plate, metric: "iron", value: "\(Int(value)) mg", df: df))
            }

        default:
            break
        }

        return (plateSamples, productSamples)
    }

    private func createPlateSample(plate: PlateAnalysisHistory, metric: String, value: String, df: DateFormatter) -> SampleRef {
        return SampleRef(
            kind: .plate,
            key: plate.id.uuidString,
            name: plate.name,
            dateISO: df.string(from: plate.analyzedDate),
            metricLabel: metric,
            metricValue: value
        )
    }

    private func createProductSample(product: Product, metric: String, value: String, df: DateFormatter) -> SampleRef {
        return SampleRef(
            kind: .product,
            key: product.barcode,
            name: product.name,
            dateISO: df.string(from: product.scannedDate),
            metricLabel: metric,
            metricValue: value
        )
    }

    // MARK: - Behavior Patterns

    private struct BehaviorPatterns {
        let frequentCategories: [String: Int]
        let highSugarProductDays: Set<String>
        let highSodiumProductDays: Set<String>
        let avgPlateScore: Double
    }

    private func analyzeBehaviorPatterns(recentPlates: [PlateAnalysisHistory], recentProducts: [Product]) -> BehaviorPatterns {
        let df = Self.dayFormatter

        let avgPlate = recentPlates.map { $0.nutritionScore }.reduce(0,+) / Double(max(1, recentPlates.count))
        var cats: [String:Int] = [:]
        var hiSugar: Set<String> = []
        var hiSodium: Set<String> = []

        for p in recentProducts {
            p.categoriesTags?.forEach { cats[$0, default: 0] += 1 }
            let day = df.string(from: p.scannedDate)
            if p.nutritionData.sugar >= 20 { hiSugar.insert(day) }
            if p.nutritionData.sodium >= 1.5 { hiSodium.insert(day) } // grams
        }

        return BehaviorPatterns(
            frequentCategories: cats,
            highSugarProductDays: hiSugar,
            highSodiumProductDays: hiSodium,
            avgPlateScore: avgPlate
        )
    }

    // MARK: - Correlation Discovery

    private func discoverCorrelations(plates: [PlateAnalysisHistory], products: [Product]) -> [CorrelationInsight] {
        guard !plates.isEmpty || !products.isEmpty else { return [] }
        let df = Self.dayFormatter

        // Map day -> avg plate score
        var dayPlateScores: [String: [Double]] = [:]
        for plate in plates { dayPlateScores[df.string(from: plate.analyzedDate), default: []].append(plate.nutritionScore) }

        // Sugar vs next-day plate score
        var sugarDays: Set<String> = []
        for prod in products where prod.nutritionData.sugar >= NutritionConstants.highSugarThreshold { sugarDays.insert(df.string(from: prod.scannedDate)) }

        func nextDay(of day: String) -> String? {
            guard let date = df.date(from: day), let next = Calendar.current.date(byAdding: .day, value: 1, to: date) else { return nil }
            return df.string(from: next)
        }

        var nextDayAfterSugarScores: [Double] = []
        var nextDayAfterNonSugarScores: [Double] = []

        let allDays = Set(dayPlateScores.keys)
        for day in allDays {
            guard let nDay = nextDay(of: day) else { continue }
            let avgScore = (dayPlateScores[nDay] ?? []).reduce(0,+) / Double(max(1, dayPlateScores[nDay]?.count ?? 0))
            if sugarDays.contains(day) {
                nextDayAfterSugarScores.append(avgScore)
            } else {
                nextDayAfterNonSugarScores.append(avgScore)
            }
        }

        var insights: [CorrelationInsight] = []
        if !nextDayAfterSugarScores.isEmpty && !nextDayAfterNonSugarScores.isEmpty {
            let a = nextDayAfterSugarScores.reduce(0,+) / Double(nextDayAfterSugarScores.count)
            let b = nextDayAfterNonSugarScores.reduce(0,+) / Double(nextDayAfterNonSugarScores.count)
            let diff = b - a // positive if non-sugar days lead to higher next-day plate scores
            if diff >= NutritionConstants.meaningfulScoreDifference { // threshold for meaningful effect
                let strength = min(1.0, diff / 2.0)
                insights.append(CorrelationInsight(
                    type: .sugarVsPlateScore,
                    description: "On days after high-sugar product scans, your plate nutrition score tends to be lower.",
                    score: strength,
                    tags: ["sugar", "plate_score"],
                    evidence: [
                        "Avg next-day score after sugar: \(String(format: "%.2f", a))",
                        "Avg next-day score after non-sugar: \(String(format: "%.2f", b))"
                    ]
                ))
            }
        }

        // Category habit: top category dominance
        var categoryCounts: [String:Int] = [:]
        for p in products { p.categoriesTags?.forEach { categoryCounts[$0, default: 0] += 1 } }
        if let (top, count) = categoryCounts.max(by: { $0.value < $1.value }), count >= NutritionConstants.minCategoryCount {
            let total = max(1, categoryCounts.values.reduce(0,+))
            let share = Double(count) / Double(total)
            if share >= NutritionConstants.categoryDominanceThreshold {
                insights.append(CorrelationInsight(
                    type: .categoryHabit,
                    description: "You frequently scan items in category ‘\(top)’. Consider balancing with alternatives.",
                    score: min(1.0, share),
                    tags: ["category", top],
                    evidence: ["\(count) of \(total) recent scans are \(top)"]
                ))
            }
        }

        // Sodium vs plate score same-day
        var sodiumDays: [String: Double] = [:]
        for prod in products { sodiumDays[df.string(from: prod.scannedDate), default: 0] += prod.nutritionData.sodium }
        let highSodiumDays = sodiumDays.filter { $0.value >= NutritionConstants.veryHighSodiumThreshold }.keys
        if !highSodiumDays.isEmpty {
            let hiScores = highSodiumDays.compactMap { dayPlateScores[$0] }.flatMap { $0 }
            let loScores = dayPlateScores.filter { !highSodiumDays.contains($0.key) }.flatMap { $0.value }
            if !hiScores.isEmpty && !loScores.isEmpty {
                let a = hiScores.reduce(0,+) / Double(hiScores.count)
                let b = loScores.reduce(0,+) / Double(loScores.count)
                let diff = b - a
                if diff >= NutritionConstants.meaningfulScoreDifference {
                    let strength = min(1.0, diff / 2.0)
                    insights.append(CorrelationInsight(
                        type: .sodiumVsPlateScore,
                        description: "Days with high-sodium products correlate with lower plate nutrition scores.",
                        score: strength,
                        tags: ["sodium", "plate_score"],
                        evidence: [
                            "Avg score high-sodium days: \(String(format: "%.2f", a))",
                            "Avg score other days: \(String(format: "%.2f", b))"
                        ]
                    ))
                }
            }
        }

        return insights
    }

    // MARK: - Recommendation Generators

    private func generateContentBasedRecommendations(deficiencies: [NutrientDeficiency]) -> [NutritionRecommendation] {
        return deficiencies
            .sorted(by: { $0.deficitMagnitude > $1.deficitMagnitude })
            .map { createRecommendationForDeficiency($0) }
    }

    private func createRecommendationForDeficiency(_ deficiency: NutrientDeficiency) -> NutritionRecommendation {
        let baseEvidence = [
            "Avg \(deficiency.nutrient.rawValue) \(Int(deficiency.avgValue)) vs target \(Int(deficiency.targetValue)) (\(deficiency.windowDays)d)",
            "Deficit: \(String(format: "%.0f%%", deficiency.deficitMagnitude * 100))"
        ] + samplesToEvidence(deficiency.samplePlates + deficiency.sampleProducts)

        switch deficiency.nutrient {
        case .fiber:
            return NutritionRecommendation(
                title: "Boost Fiber Intake",
                message: "Add legumes, berries, chia seeds, or whole grains to reach your daily ~25g fiber target.",
                reason: "Average fiber intake appears below recommended levels",
                relevanceScore: NutritionConstants.fiberRelevanceBase + deficiency.deficitMagnitude * 0.2,
                type: .deficiencyCorrection,
                tags: ["fiber"],
                evidence: baseEvidence
            )
        case .protein:
            return NutritionRecommendation(
                title: "Lean Protein Top-Up",
                message: "Consider eggs, greek yogurt, tofu, beans, or lean fish to raise protein on low days.",
                reason: "Protein intake trends below target",
                relevanceScore: NutritionConstants.proteinRelevanceBase + deficiency.deficitMagnitude * 0.25,
                type: .deficiencyCorrection,
                tags: ["protein"],
                evidence: baseEvidence
            )
        case .vitaminC:
            return NutritionRecommendation(
                title: "Add Vitamin C Sources",
                message: "Citrus, bell peppers, kiwi, and strawberries can lift vitamin C levels.",
                reason: "Vitamin C appears suboptimal",
                relevanceScore: NutritionConstants.vitaminCRelevanceBase + deficiency.deficitMagnitude * 0.3,
                type: .deficiencyCorrection,
                tags: ["vitaminC"],
                evidence: baseEvidence
            )
        default:
            return NutritionRecommendation(
                title: "Micronutrient Gap",
                message: "Consider leafy greens, legumes, nuts, and seeds to round out micronutrients.",
                reason: "Detected micronutrient gap",
                relevanceScore: NutritionConstants.micronutrientRelevanceBase + deficiency.deficitMagnitude * 0.2,
                type: .deficiencyCorrection,
                tags: [deficiency.nutrient.rawValue],
                evidence: baseEvidence
            )
        }
    }

    private func generateSwapAndRiskRecommendations(plates: [PlateAnalysisHistory], products: [Product], preferences: DietaryPreferencesManager) -> [NutritionRecommendation] {
        var recs: [NutritionRecommendation] = []

        // Sugar swap suggestions
        let highSugarProducts = products.filter { $0.nutritionData.sugar >= NutritionConstants.highSugarThreshold }
        let highSugarCount = highSugarProducts.count
        if highSugarCount >= NutritionConstants.minHighSugarProductCount {
            let examples = Array(highSugarProducts.sorted { $0.nutritionData.sugar > $1.nutritionData.sugar }.prefix(2))
            let exampleNames = examples.map { "\($0.name) (\(Int($0.nutritionData.sugar))g)" }
            recs.append(NutritionRecommendation(
                title: "Reduce Sugary Drinks",
                message: "Swap soda or sweetened juices for sparkling water with citrus or unsweetened iced tea.",
                reason: "Frequent high-sugar product scans",
                relevanceScore: NutritionConstants.sugarSwapRelevance,
                type: .swapSuggestion,
                tags: ["sugar"],
                evidence: [
                    "Window: last \(productWindowDays)d",
                    "High-sugar scans (≥\(Int(NutritionConstants.highSugarThreshold))g): \(highSugarCount)"
                ] + (exampleNames.isEmpty ? [] : ["Examples: \(exampleNames.joined(separator: ", "))"])
            ))
        }

        // Sodium risk alert
        let highSodiumProducts = products.filter { $0.nutritionData.sodium >= NutritionConstants.highSodiumThreshold }
        let highSodiumCount = highSodiumProducts.count
        if highSodiumCount >= NutritionConstants.minHighSodiumProductCount {
            let examples = Array(highSodiumProducts.sorted { $0.nutritionData.sodium > $1.nutritionData.sodium }.prefix(2))
            let exampleNames = examples.map { "\($0.name) (\(String(format: "%.1f", $0.nutritionData.sodium))g)" }
            recs.append(NutritionRecommendation(
                title: "Watch Sodium",
                message: "Look for ‘low sodium’ labels and rinse canned foods; favor fresh over processed.",
                reason: "Multiple high-sodium product scans",
                relevanceScore: NutritionConstants.sodiumRiskRelevance,
                type: .riskAlert,
                tags: ["sodium"],
                evidence: [
                    "Window: last \(productWindowDays)d",
                    "High-sodium scans (≥\(String(format: "%.1f", NutritionConstants.highSodiumThreshold))g): \(highSodiumCount)"
                ] + (exampleNames.isEmpty ? [] : ["Examples: \(exampleNames.joined(separator: ", "))"])
            ))
        }

        // Synergy: pair fiber with protein on low-fiber + high-carb days
        let lowFiberPlates = plates.filter { Double($0.micronutrients?.fiberG ?? 0) < NutritionConstants.lowFiberPlateThreshold }
        if lowFiberPlates.count >= NutritionConstants.minLowFiberPlateCount {
            let examplePlates = Array(lowFiberPlates.prefix(2)).map { $0.name }
            recs.append(NutritionRecommendation(
                title: "Fiber + Protein Pairing",
                message: "Add beans, lentils, or veg to carb-heavy meals for steadier energy and fullness.",
                reason: "Several low-fiber plates detected",
                relevanceScore: NutritionConstants.fiberPairingRelevance,
                type: .synergyPairing,
                tags: ["fiber", "satiety"],
                evidence: [
                    "Window: last \(plateWindowDays)d",
                    "Low-fiber plates (<\(Int(NutritionConstants.lowFiberPlateThreshold))g): \(lowFiberPlates.count)"
                ] + (examplePlates.isEmpty ? [] : ["Examples: \(examplePlates.joined(separator: ", "))"])
            ))
        }

        recs += generateSubstitutionSuggestions(products: products)

        // Allergy safety: simple alert if products include likely allergens and user has preferences
        if preferences.hasAllergies, let ingredientsTexts = products.compactMap({ $0.ingredients?.lowercased() }) as [String]? {
            let allergyHits = preferences.selectedAllergies.filter { allergy in
                ingredientsTexts.contains { $0.contains(allergy.rawValue.replacingOccurrences(of: "_", with: " ")) }
            }
            if !allergyHits.isEmpty {
                recs.append(NutritionRecommendation(
                    title: "Allergen Check",
                    message: "Recent products may contain: \(allergyHits.map { $0.displayName }.joined(separator: ", ")). Verify labels before consuming.",
                    reason: "Allergies in profile",
                    relevanceScore: NutritionConstants.allergenRelevance,
                    type: .riskAlert,
                    tags: ["allergy"],
                    evidence: []
                ))
            }
        }

        return recs
    }

    private func generateSubstitutionSuggestions(products: [Product]) -> [NutritionRecommendation] {
        guard !products.isEmpty else { return [] }
        var byCategory: [String: [Product]] = [:]
        for product in products {
            guard let category = product.categoriesTags?.first, !category.isEmpty else { continue }
            byCategory[category, default: []].append(product)
        }

        struct Candidate {
            let delta: Double
            let category: String
            let metric: String
            let high: Product
            let low: Product
        }

        var candidates: [Candidate] = []
        for (category, items) in byCategory where items.count >= NutritionConstants.substitutionMinCategoryCount {
            let metrics: [(String, (Product) -> Double, Double)] = [
                ("sugar", { $0.nutritionData.sugar }, NutritionConstants.substitutionSugarDeltaG),
                ("sodium", { $0.nutritionData.sodium }, NutritionConstants.substitutionSodiumDeltaG),
                ("fat", { $0.nutritionData.fat }, NutritionConstants.substitutionFatDeltaG)
            ]
            for (label, getter, threshold) in metrics {
                guard let high = items.max(by: { getter($0) < getter($1) }),
                      let low = items.min(by: { getter($0) < getter($1) }) else { continue }
                let highVal = getter(high)
                let lowVal = getter(low)
                let delta = highVal - lowVal
                if delta >= threshold, high.name != low.name {
                    candidates.append(Candidate(delta: delta, category: category, metric: label, high: high, low: low))
                }
            }
        }

        if candidates.isEmpty { return [] }
        candidates.sort { $0.delta > $1.delta }

        func displayCategory(_ raw: String) -> String {
            var value = raw
            if value.hasPrefix("en:") { value = String(value.dropFirst(3)) }
            return value.replacingOccurrences(of: "_", with: " ")
        }

        var recs: [NutritionRecommendation] = []
        for candidate in candidates.prefix(NutritionConstants.substitutionMaxRecs) {
            let catLabel = displayCategory(candidate.category)
            let highVal = candidate.metric == "sodium" ? String(format: "%.1f", candidate.high.nutritionData.sodium)
                : String(format: "%.1f", candidate.metric == "sugar" ? candidate.high.nutritionData.sugar : candidate.high.nutritionData.fat)
            let lowVal = candidate.metric == "sodium" ? String(format: "%.1f", candidate.low.nutritionData.sodium)
                : String(format: "%.1f", candidate.metric == "sugar" ? candidate.low.nutritionData.sugar : candidate.low.nutritionData.fat)
            let delta = String(format: "%.1f", candidate.delta)
            recs.append(NutritionRecommendation(
                title: "Swap Within Category",
                message: "Within \(catLabel), try \(candidate.low.name) instead of \(candidate.high.name) to cut \(candidate.metric) by ~\(delta) g.",
                reason: "Lower nutrient option in the same category",
                relevanceScore: NutritionConstants.sugarSwapRelevance,
                type: .swapSuggestion,
                tags: ["substitution", candidate.metric, candidate.category],
                evidence: [
                    "Category: \(catLabel)",
                    "\(candidate.high.name): \(highVal) g \(candidate.metric)",
                    "\(candidate.low.name): \(lowVal) g \(candidate.metric)"
                ]
            ))
        }
        return recs
    }

    // MARK: - Evidence helpers
    private func samplesToEvidence(_ samples: [SampleRef]) -> [String] {
        guard !samples.isEmpty else { return [] }
        let items = samples.prefix(2).map { s in "\(s.name) (\(s.metricLabel): \(s.metricValue))" }
        return ["Examples: \(items.joined(separator: ", "))"]
    }

    private func mapCorrelationsToRecommendations(_ correlations: [CorrelationInsight]) -> [NutritionRecommendation] {
        correlations.map { c in
            NutritionRecommendation(
                title: correlationTitle(c.type),
                message: c.description,
                reason: "Observed in your recent history",
                relevanceScore: NutritionConstants.baseRelevanceScore + 0.4 * c.score,
                type: .correlationInsight,
                tags: c.tags,
                evidence: c.evidence
            )
        }
    }

    private func correlationTitle(_ type: CorrelationInsight.CorrelationType) -> String {
        switch type {
        case .sugarVsPlateScore: return "Sugar Affects Plate Score"
        case .sodiumVsPlateScore: return "Sodium Affects Plate Score"
        case .categoryHabit: return "Category Habit Detected"
        case .timeOfDayHabit: return "Time-of-Day Pattern"
        case .micronutrientGap: return "Micronutrient Gap Pattern"
        }
    }

    /// Fits a small ridge-regularized linear model and maps learned weights to human-friendly recommendations.
    /// Side-effect: persists a snapshot of (featureNames, coefficients) for warm-start fallback.
    private func generateMLRecommendations(training: MLTrainingData) -> [NutritionRecommendation] {
        func persistSnapshotIfNeeded(featureNames: [String], coefficients: [Double]) {
            // Persist learned coefficients and feature ordering for warm-starts
            LocalRecommendationML.saveSnapshot(names: featureNames, coeffs: coefficients)
        }

        var recs: [NutritionRecommendation] = []
        let model = LinearRegressor()
        model.fit(data: training, lambda: NutritionConstants.mlRegularization)
        let w = model.coefficients

        // Save a snapshot so we can warm-start or fall back when history is missing
        persistSnapshotIfNeeded(featureNames: training.space.featureNames, coefficients: w)

        guard w.count == training.space.featureNames.count else { return recs }

        // Map weights to names
        let pairs = Array(zip(training.space.featureNames, w))
        // Exclude intercept for ranking actions
        let nonIntercept = pairs.filter { $0.0 != "intercept" }

        // Identify top negative and positive drivers of next-day plate score
        let mostNegative = nonIntercept.sorted { $0.1 < $1.1 }.prefix(3)
        let mostPositive = nonIntercept.sorted { $0.1 > $1.1 }.prefix(3)

        // Generate action for negatives: suggest reducing those features
        for (name, weight) in mostNegative {
            guard weight < -NutritionConstants.mlWeightThreshold else { continue }
            let message: String
            let tag: String
            if name == "sugar_g" {
                message = "Reducing daily sugar could improve tomorrow’s plate score based on your data."
                tag = "sugar"
            } else if name == "sodium_g" {
                message = "Lower sodium days correlate with better next-day plate quality in your history."
                tag = "sodium"
            } else if name.hasPrefix("cat_") {
                let cat = String(name.dropFirst(4))
                message = "This category appears linked to lower next-day plate scores. Consider alternatives."
                tag = cat
            } else {
                message = "This factor seems to reduce next-day plate quality; try to moderate it."
                tag = name
            }
            let evidence = [
                String(format: "Learned coefficient: %.3f (negative)", weight),
                "Target: improve predicted next-day score"
            ]
            recs.append(NutritionRecommendation(
                title: friendlyTitle(for: name, positive: false),
                message: message,
                reason: "Learned from your recent data",
                relevanceScore: min(1.0, NutritionConstants.baseRelevanceScore + min(0.4, abs(weight))),
                type: .correlationInsight,
                tags: [tag],
                evidence: evidence
            ))
        }

        // Generate action for positives: suggest increasing those features
        for (name, weight) in mostPositive {
            guard weight > NutritionConstants.mlWeightThreshold else { continue }
            let message: String
            let tag: String
            if name == "fiber_g" {
                message = "Days with more fiber trend toward better next-day plate scores for you."
                tag = "fiber"
            } else if name == "protein_g" {
                message = "Higher protein days associate with improved next-day plate quality in your history."
                tag = "protein"
            } else if name.hasPrefix("cat_") {
                let cat = String(name.dropFirst(4))
                message = "This category aligns with better next-day plate scores for you."
                tag = cat
            } else {
                message = "This factor tends to improve next-day plate quality in your data."
                tag = name
            }
            let evidence = [
                String(format: "Learned coefficient: %.3f (positive)", weight),
                "Target: improve predicted next-day score"
            ]
            recs.append(NutritionRecommendation(
                title: friendlyTitle(for: name, positive: true),
                message: message,
                reason: "Learned from your recent data",
                relevanceScore: min(1.0, NutritionConstants.baseRelevanceScore + min(0.4, abs(weight))),
                type: .correlationInsight,
                tags: [tag],
                evidence: evidence
            ))
        }

        return recs
    }

    private func friendlyTitle(for feature: String, positive: Bool) -> String {
        switch feature {
        case "sugar_g": return positive ? "Maintain Lower Sugar Days" : "Reduce Daily Sugar"
        case "sodium_g": return positive ? "Keep Sodium in Check" : "Lower Daily Sodium"
        case "fiber_g": return positive ? "Increase Dietary Fiber" : "Reduce Low-Fiber Days"
        case "protein_g": return positive ? "Support with Protein" : "Avoid Very Low Protein"
        default:
            if feature.hasPrefix("cat_") { return positive ? "Lean Into Helpful Category" : "Dial Back a Category" }
            return positive ? "Reinforce Helpful Pattern" : "Reduce Harmful Pattern"
        }
    }

    // MARK: - Differential Privacy

    private func applyDifferentialPrivacy(_ recommendations: [NutritionRecommendation]) -> [NutritionRecommendation] {
        guard !recommendations.isEmpty else { return recommendations }
        let sensitivity = 1.0 / Double(recommendations.count)
        let noiseScale = sensitivity / max(privacyBudget, 0.1)
        return recommendations.map { rec in
            var r = rec
            let noise = laplacianNoise(scale: noiseScale)
            r.relevanceScore = max(0, min(1.0, r.relevanceScore + noise))
            return r
        }
    }

    private func laplacianNoise(scale: Double) -> Double {
        guard scale > 0 else { return 0 }
        let u = Double.random(in: -0.5...0.5)
        let sign = u >= 0 ? 1.0 : -1.0
        return -scale * sign * log(1 - 2 * abs(u))
    }

    // MARK: - New Adaptive Trend Insights

    func generateAdaptiveTrendInsights(plates: [PlateAnalysisHistory], products: [Product]) -> [NutritionRecommendation] {
        let timelines = calculateDailyNutrientTimelines(plates: plates, products: products)
        let recentDays = 7
        let baselineDays = 30

        func build(_ nutrient: NutrientDeficiency.Nutrient, name: String, iconTag: String) -> NutritionRecommendation? {
            guard let series = timelines[nutrient], !series.isEmpty else { return nil }
            let t = NutritionConstants.Adaptive.trend(valuesByDay: series, recentDays: recentDays, baselineDays: baselineDays)
            // If no signal, skip
            if t.recent == 0 && t.baseline == 0 { return nil }
            let delta = t.deltaPct
            let dir = delta >= 0 ? "up" : "down"
            let absDelta = abs(delta)
            let title = absDelta >= 5 ? "\(name.capitalized) trend is \(dir) \(String(format: "%.0f%%", absDelta))" : "\(name.capitalized) trend update"
            let message: String
            if delta >= 8 {
                message = "Your \(name) intake is up \(String(format: "%.0f%%", absDelta)) from your usual pattern. Nice momentum!"
            } else if delta <= -8 {
                message = "Your \(name) intake is down \(String(format: "%.0f%%", absDelta)) vs your usual. Want ideas to boost it?"
            } else {
                message = "Your \(name) is close to your usual pattern."
            }
            return NutritionRecommendation(
                title: title,
                message: message,
                reason: "Compared your last \(recentDays)d to your typical \(baselineDays)d",
                relevanceScore: NutritionConstants.baseRelevanceScore,
                type: .correlationInsight,
                tags: [iconTag, "trend"],
                evidence: [
                    String(format: "Recent avg: %.1f", t.recent),
                    String(format: "Baseline avg: %.1f", t.baseline)
                ]
            )
        }

        var recs: [NutritionRecommendation] = []
        if let r = build(.fiber, name: "fiber", iconTag: "fiber") { recs.append(r) }
        if let r = build(.protein, name: "protein", iconTag: "protein") { recs.append(r) }
        if let r = build(.vitaminC, name: "vitamin C", iconTag: "vitaminC") { recs.append(r) }
        if let r = build(.iron, name: "iron", iconTag: "iron") { recs.append(r) }
        return recs
    }

    func qualitativeMealMessage(for plate: PlateAnalysisHistory) -> NutritionRecommendation? {
        // Derive simple qualitative assessment based on relative macros and fiber
        let fiber = Double(plate.micronutrients?.fiberG ?? 0)
        let protein = Double(plate.protein)
        // Heuristics: treat as light if very low compared to simple thresholds; these are not "targets" but identification of lightness
        let isProteinLight = protein < 15
        let isFiberLight = fiber < 6

        let title: String
        let message: String
        if isProteinLight && isFiberLight {
            title = "Could Use More Protein and Fiber"
            message = "Consider adding beans, lentils, eggs, or greens for more fullness and balance."
        } else if isProteinLight {
            title = "This Meal Is Light on Protein"
            message = "Add eggs, beans, tofu, or Greek yogurt for a more filling plate."
        } else if isFiberLight {
            title = "This Meal Is Light on Fiber"
            message = "Add veggies, legumes, berries, or whole grains to boost fiber."
        } else {
            title = "Nice Balance"
            message = "Looks balanced — keep what works for you."
        }

        return NutritionRecommendation(
            title: title,
            message: message,
            reason: "Qualitative assessment without numeric targets",
            relevanceScore: NutritionConstants.baseRelevanceScore,
            type: .recommendation,
            tags: ["qualitative"],
            evidence: []
        )
    }
}

// (Intentionally no underscore-named computed properties to avoid SwiftData macro collisions)


