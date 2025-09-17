import Foundation
import SwiftUI
import SwiftData
import UIKit
#if canImport(ARKit)
import ARKit
#endif

@MainActor
final class PlateAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResult: PlateAnalysis?
    @Published var lastAnalysisResult: PlateAnalysis?
    @Published var lastAnalyzedImage: UIImage?
    // Keep a handle to the most-recently inserted history row so we can enrich it after AI returns
    private var currentHistory: PlateAnalysisHistory?

    private let lastAnalysisKey = "lastPlateAnalysis"
    private let openAI = OpenAIService()

    func loadLastAnalysisFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: lastAnalysisKey),
           let decoded = try? JSONDecoder().decode(PlateAnalysis.self, from: data) {
            lastAnalysisResult = decoded
        }
        if let imgData = UserDefaults.standard.data(forKey: "\(lastAnalysisKey)_image"),
           let img = UIImage(data: imgData) {
            lastAnalyzedImage = img
        }
    }

    func saveLastAnalysisToDefaults(analysis: PlateAnalysis, image: UIImage?) {
        lastAnalysisResult = analysis
        lastAnalyzedImage = image
        if let encoded = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(encoded, forKey: lastAnalysisKey)
        }
        if let data = image?.jpegData(compressionQuality: 0.4) {
            UserDefaults.standard.set(data, forKey: "\(lastAnalysisKey)_image")
        }
    }

    func nutritionScore(for scan: ARPlateScanNutrition) -> Double {
        let macroSum = Double(scan.protein + scan.carbs + scan.fat)
        return min(10, max(0, macroSum / 30.0 * 10.0))
    }

    func buildNutritionPrompt(ctx: OpenAIService.PlateContext) -> String {
        return """
        You are an expert nutritionist and health coach. Analyze this plate image along with the provided AR measurements and produce the entire nutrition assessment (macros, calories, micronutrients) without relying on any client estimations.

        **MEASUREMENT DATA:**
        • Food detected: \(ctx.label) (confidence: \(String(format: "%.1f", ctx.confidence * 100))%)
        • Estimated volume: \(Int(ctx.volumeML)) ml
        • Note: Any macros/calories in client context may be placeholders. You must estimate calories and P/C/F grams yourself from the image and portion size.
        \(ctx.method != nil ? "• Detection method: \(ctx.method!)" : "")
        \(ctx.device != nil ? "• Device: \(ctx.device!)" : "")

        **YOUR TASK:**
        Provide a comprehensive nutritional analysis. Estimate calories and macronutrients (protein, carbs, fat) for this portion and include a clear numeric summary. Also include specific mentions of micronutrients present in this food.

        **REQUIRED RESPONSE STRUCTURE:**
        1. Food verification and portion assessment (1-2 sentences)
        2. Estimated calories and macronutrients (P/C/F grams) for this plate as a short bullet list
        3. Micronutrient analysis (vitamins, minerals, antioxidants, fiber) with terms like: vitamin C, vitamin A, vitamin K, vitamin E, B vitamins, folate, iron, calcium, potassium, magnesium, zinc, antioxidants, omega-3 fatty acids
        4. Macronutrient balance comment (1 sentence)
        5. Specific recommendations (2-3 actionable suggestions)

        CRITICAL: Mention at least 3-4 specific micronutrients using the exact terminology above.
        """
    }

    @discardableResult
    func savePlateAnalysisToHistory(analysis: PlateAnalysis, image: UIImage?, scan: ARPlateScanNutrition, modelContext: ModelContext) -> PlateAnalysisHistory {
        let plateInsights: [PlateInsight] = analysis.insights.map { insight in
            let type: PlateInsight.PlateInsightType
            switch insight.type {
            case .positive: type = .positive
            case .suggestion: type = .suggestion
            case .warning: type = .warning
            }
            return PlateInsight(type: type, title: insight.title, description: insight.description)
        }
        let plateIngredients: [PlateIngredient] = analysis.ingredients.map { PlateIngredient(name: $0.name, amount: $0.amount) }
        let imageData = image?.jpegData(compressionQuality: 0.8)
        let mealName = scan.label
        let history = PlateAnalysisHistory(
            name: mealName,
            imageData: imageData,
            nutritionScore: analysis.nutritionScore,
            description: analysis.description,
            protein: analysis.macronutrients.protein,
            carbs: analysis.macronutrients.carbs,
            fat: analysis.macronutrients.fat,
            calories: analysis.macronutrients.calories,
            ingredients: plateIngredients,
            insights: plateInsights,
            micronutrients: analysis.micronutrients,
            connections: analysis.connections
        )
        modelContext.insert(history)
        if let img = image { ImageCacheService.shared.saveImage(img, forKey: history.cacheKey) }
        currentHistory = history
        return history
    }

    func handleScanResult(scan: ARPlateScanNutrition, image: UIImage, modelContext: ModelContext) async {
        // 1) Initial mapping (nutrition deferred to OpenAI)
        let baseAnalysis = PlateAnalysis(
            nutritionScore: 0,
            description: "Estimated \(scan.label) • \(Int(scan.volumeML)) ml",
            macronutrients: Macronutrients(
                protein: 0,
                carbs: 0,
                fat: 0,
                calories: 0
            ),
            ingredients: [Ingredient(name: scan.label.capitalized, amount: scan.massG > 0 ? "\(Int(scan.massG)) g" : "—")],
            insights: [
                Insight(type: .positive, title: "Hands-free portioning", description: "Volume derived from depth above the plate plane."),
                Insight(type: .suggestion, title: "For best accuracy", description: "Move slightly left/right until prompted to hold still.")
            ],
            micronutrients: nil,
            connections: nil
        )

        isAnalyzing = true
        saveLastAnalysisToDefaults(analysis: baseAnalysis, image: image)
        let historyRef = savePlateAnalysisToHistory(analysis: baseAnalysis, image: image, scan: scan, modelContext: modelContext)

        // 2) Enrich with OpenAI
        do {
            #if canImport(ARKit)
            let method = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) ? "LiDAR" : "DualCameraDepth"
            #else
            let method = "Simulator/mock"
            #endif
            print("🔵 [VM] Preparing OpenAI request: label=\(scan.label) conf=\(String(format: "%.2f", scan.confidence)) vol=\(Int(scan.volumeML))ml")
            let ctx = OpenAIService.PlateContext(
                label: scan.label,
                confidence: scan.confidence,
                volumeML: scan.volumeML,
                massG: 0,
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                planeStableScore: nil,
                device: UIDevice.current.model,
                method: method
            )
            // Ask AI for structured nutrition
            let structured = try await openAI.sendPlateForNutrition(image: image, context: ctx)
            print("🟢 [VM] Received structured nutrition: title=\(structured.title) score=\(String(format: "%.2f", structured.score))")

            // Map AI response into our domain model
            var insights: [Insight] = baseAnalysis.insights
            // Add AI-provided insights
            for i in structured.insights {
                let t: Insight.InsightType
                switch i.type.lowercased() {
                case "positive": t = .positive
                case "warning": t = .warning
                default: t = .suggestion
                }
                insights.append(Insight(type: t, title: i.title, description: i.description))
            }
            // Prepare micronutrients and connections for the analysis model (UI will render them)
            let microModel: Micronutrients? = {
                guard let m = structured.micros else { return nil }
                return Micronutrients(
                    fiberG: m.fiber_g != nil ? Int((m.fiber_g!).rounded()) : nil,
                    vitaminCMg: m.vitamin_c_mg != nil ? Int((m.vitamin_c_mg!).rounded()) : nil,
                    ironMg: m.iron_mg != nil ? Int((m.iron_mg!).rounded()) : nil,
                    other: m.other
                )
            }()
            let connections = structured.connections

            let final = PlateAnalysis(
                nutritionScore: structured.score,
                description: structured.title,
                macronutrients: Macronutrients(
                    protein: Int((structured.macros.protein_g).rounded()),
                    carbs: Int((structured.macros.carbs_g).rounded()),
                    fat: Int((structured.macros.fat_g).rounded()),
                    calories: Int((structured.macros.calories_kcal).rounded())
                ),
                ingredients: structured.ingredients.map { Ingredient(name: $0.name, amount: $0.amount) },
                insights: insights,
                micronutrients: microModel,
                connections: connections
            )
            analysisResult = final
            print("🟢 [VM] Analysis updated and displayed")

            // Enrich the saved history row with AI results so History shows full details
            if let history = currentHistory ?? historyRef as PlateAnalysisHistory? {
                history.name = structured.title
                history.nutritionScore = structured.score
                history.analysisDescription = structured.title
                history.protein = Int((structured.macros.protein_g).rounded())
                history.carbs = Int((structured.macros.carbs_g).rounded())
                history.fat = Int((structured.macros.fat_g).rounded())
                history.calories = Int((structured.macros.calories_kcal).rounded())
                // Re-encode ingredients/insights/micros/connections
                let updatedIngredients = structured.ingredients.map { PlateIngredient(name: $0.name, amount: $0.amount) }
                let updatedInsights: [PlateInsight] = insights.map { i in
                    let t: PlateInsight.PlateInsightType
                    switch i.type {
                    case .positive: t = .positive
                    case .suggestion: t = .suggestion
                    case .warning: t = .warning
                    }
                    return PlateInsight(type: t, title: i.title, description: i.description)
                }
                history.ingredientsData = (try? JSONEncoder().encode(updatedIngredients)) ?? Data()
                history.insightsData = (try? JSONEncoder().encode(updatedInsights)) ?? Data()
                if let microModel {
                    history.microsData = try? JSONEncoder().encode(microModel)
                }
                if let connections {
                    history.connectionsData = try? JSONEncoder().encode(connections)
                }
            }
        } catch {
            // Fallback to base analysis on failure, but surface the error for the user
            var fallback = baseAnalysis
            let message = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
            let hint = message.isEmpty ? "AI request failed. Check API key and network." : message
            print("🔴 [VM] OpenAI error: \(hint)")
            fallback = PlateAnalysis(
                nutritionScore: baseAnalysis.nutritionScore,
                description: baseAnalysis.description,
                macronutrients: baseAnalysis.macronutrients,
                ingredients: baseAnalysis.ingredients,
                insights: baseAnalysis.insights + [
                    Insight(type: .warning, title: "AI Unavailable", description: hint)
                ],
                micronutrients: nil,
                connections: nil
            )
            analysisResult = fallback
        }

        isAnalyzing = false
    }
}
