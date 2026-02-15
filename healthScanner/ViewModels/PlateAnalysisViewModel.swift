import Foundation
import SwiftUI
import SwiftData
import UIKit
import Vision
import CoreGraphics
import AVFoundation

protocol AggregatorServicing {
    func upsertDaily(for date: Date, modelContext: ModelContext) async
}

extension AggregatorService: AggregatorServicing {}

protocol ImageCacheServicing {
    func saveImage(_ image: UIImage, forKey key: String)
}

extension ImageCacheService: ImageCacheServicing {}

@MainActor
final class PlateAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResult: PlateAnalysis?
    @Published var lastAnalysisResult: PlateAnalysis?
    @Published var lastAnalyzedImage: UIImage?

    @Published var transientCategories: [String] = []
    @Published var transientVolumeML: Float?
    @Published var transientMassG: Float?
    @Published var transientDepthSnapshot: DepthFrameSnapshot?

    // Allows UI to pass lightweight, non-persistent category hints from on-device classification
    func setTransientCategories(_ categories: [String]) {
        self.transientCategories = categories
    }

    // Allows UI to pass lightweight, non-persistent scan metrics from depth-based scanners.
    func setTransientScanMetrics(volumeML: Float?, massG: Float?) {
        self.transientVolumeML = volumeML
        self.transientMassG = massG
    }

    func setTransientDepthSnapshot(_ snapshot: DepthFrameSnapshot?) {
        self.transientDepthSnapshot = snapshot
    }

    private var currentHistory: PlateAnalysisHistory?
    private let lastAnalysisKey = "lastPlateAnalysis"
    private let lastAnalysisImagePathKey = "lastPlateAnalysis_imagePath"
    private let backendClient: PlateScanAPIClient
    private let aggregatorService: AggregatorServicing
    private let imageCacheService: ImageCacheServicing

    init(
        backendClient: PlateScanAPIClient = BackendAPIClient.shared,
        aggregatorService: AggregatorServicing = AggregatorService.shared,
        imageCacheService: ImageCacheServicing = ImageCacheService.shared
    ) {
        self.backendClient = backendClient
        self.aggregatorService = aggregatorService
        self.imageCacheService = imageCacheService
    }

    func loadLastAnalysisFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: lastAnalysisKey),
           let decoded = try? JSONDecoder().decode(PlateAnalysis.self, from: data) {
            lastAnalysisResult = decoded
        }
        if let path = UserDefaults.standard.string(forKey: lastAnalysisImagePathKey),
           let imgData = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let img = UIImage(data: imgData) {
            lastAnalyzedImage = img
            return
        }

        // Backward compatibility: migrate legacy image bytes from UserDefaults to file storage.
        if let legacyData = UserDefaults.standard.data(forKey: "\(lastAnalysisKey)_image"),
           let img = UIImage(data: legacyData) {
            lastAnalyzedImage = img
            persistLastAnalyzedImageToDisk(img)
            UserDefaults.standard.removeObject(forKey: "\(lastAnalysisKey)_image")
        }
    }

    func saveLastAnalysisToDefaults(analysis: PlateAnalysis, image: UIImage?) {
        lastAnalysisResult = analysis
        lastAnalyzedImage = image
        if let encoded = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(encoded, forKey: lastAnalysisKey)
        }
        if let image {
            persistLastAnalyzedImageToDisk(image)
        }
        UserDefaults.standard.removeObject(forKey: "\(lastAnalysisKey)_image")
    }

    @discardableResult
    func savePlateAnalysisToHistory(analysis: PlateAnalysis, image: UIImage?, modelContext: ModelContext) -> PlateAnalysisHistory {
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
        let mealName = analysis.description

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
        
        // Event-driven aggregate update for the plate's analysis day
        let analyzedDate = history.analyzedDate
        let aggregatorService = self.aggregatorService
        Task { @MainActor [analyzedDate, modelContext, aggregatorService] in
            await aggregatorService.upsertDaily(for: analyzedDate, modelContext: modelContext)
        }
        
        if let img = image {
            imageCacheService.saveImage(img, forKey: history.cacheKey)
        }
        currentHistory = history
        return history
    }

    func detectFoodRegions(in image: UIImage, maxRegions: Int = 3) -> [ImagePreprocessor.Result] {
        let regions = ImagePreprocessor.preprocessFoodRegions(image, maxRegions: maxRegions, padding: 0.08, confidenceThreshold: 0.05)
        return regions
    }

    func analyzeSelectedRegions(_ regions: [ImagePreprocessor.Result], originalImage: UIImage, modelContext: ModelContext) async {
        guard !regions.isEmpty else { return await handleImageAnalysis(image: originalImage, modelContext: modelContext) }
        let imageForUpload = ImagePreprocessor.mosaic(from: regions, columns: 1, spacing: 8, background: .black) ?? regions[0].image
        await analyzePreparedImage(imageForUpload, regions: regions, originalImage: originalImage, modelContext: modelContext)
    }

    private func analyzePreparedImage(_ uploadImage: UIImage, regions: [ImagePreprocessor.Result]?, originalImage: UIImage, modelContext: ModelContext) async {
        let baseAnalysis = PlateAnalysis(
            nutritionScore: 0,
            description: "Analyzing food image...",
            macronutrients: Macronutrients(
                protein: 0,
                carbs: 0,
                fat: 0,
                calories: 0
            ),
            ingredients: [Ingredient(name: "Analyzing...", amount: "—")],
            insights: [
                Insight(type: .positive, title: "Image uploaded", description: "Analyzing your plate for nutritional content."),
                Insight(type: .suggestion, title: "Contacting backend", description: "We are analyzing your meal now.")
            ],
            micronutrients: nil,
            connections: nil
        )

        isAnalyzing = true
        saveLastAnalysisToDefaults(analysis: baseAnalysis, image: originalImage)
        let historyRef = savePlateAnalysisToHistory(analysis: baseAnalysis, image: originalImage, modelContext: modelContext)

        do {
            let resized = resizedImage(uploadImage, maxSide: 1024)
            guard let imageData = resized.jpegData(compressionQuality: 0.75) else {
                throw BackendAPIError.encodingFailed
            }

            var contextPayload: [String: Any] = [
                "device": UIDevice.current.model,
                "method": "Image Analysis"
            ]
            if let volumeML = transientVolumeML {
                contextPayload["volume_ml"] = volumeML
            }
            if let massG = transientMassG {
                contextPayload["mass_g_est"] = massG
            }
            if let regions {
                let boxes: [[String: Int]] = regions.map { r in
                    [
                        "x": Int(r.boundingBox.origin.x),
                        "y": Int(r.boundingBox.origin.y),
                        "width": Int(r.boundingBox.size.width),
                        "height": Int(r.boundingBox.size.height)
                    ]
                }
                let pixels: [Int] = regions.map { $0.pixelCount }
                let confidences: [Float] = regions.map { $0.confidence }
                contextPayload["regions"] = [
                    "bboxes": boxes,
                    "pixels": pixels,
                    "confidences": confidences
                ]
            }
            let contextData = try JSONSerialization.data(withJSONObject: contextPayload, options: [])
            let contextJSON = String(data: contextData, encoding: .utf8)

            let response = try await backendClient.postPlateScanAI(
                imageData: imageData,
                contextJSON: contextJSON
            )

            let analysis = mapPlateAnalysis(response.analysis)
            analysisResult = analysis
            saveLastAnalysisToDefaults(analysis: analysis, image: originalImage)

            if let history = currentHistory ?? historyRef as PlateAnalysisHistory? {
                update(history: history, with: analysis)
            }
        } catch {
            let message = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
            let hint = message.isEmpty ? "Backend request failed. Check API configuration and network." : message

            let fallback = PlateAnalysis(
                nutritionScore: baseAnalysis.nutritionScore,
                description: "Analysis unavailable",
                macronutrients: baseAnalysis.macronutrients,
                ingredients: [Ingredient(name: "Food items", amount: "Unknown")],
                insights: [
                    Insight(type: .warning, title: "Backend Unavailable", description: hint)
                ],
                micronutrients: nil,
                connections: nil
            )
            analysisResult = fallback
        }

        isAnalyzing = false
    }

    func handleImageAnalysis(image: UIImage, modelContext: ModelContext) async {
        // Detect multiple regions; if none, fall back to single-region preprocess
        let regions = detectFoodRegions(in: image, maxRegions: 3)
        if regions.count > 1 {
            let mosaic = ImagePreprocessor.mosaic(from: regions, columns: 1, spacing: 8, background: .black) ?? regions[0].image
            await analyzePreparedImage(mosaic, regions: regions, originalImage: image, modelContext: modelContext)
        } else if let first = regions.first {
            await analyzePreparedImage(first.image, regions: [first], originalImage: image, modelContext: modelContext)
        } else {
            // Fallback to original single preprocess
            let pre = ImagePreprocessor.preprocessFoodImage(image)
            await analyzePreparedImage(pre.image, regions: [pre], originalImage: image, modelContext: modelContext)
        }
    }

    private func resizedImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrentSide = max(size.width, size.height)
        guard maxCurrentSide > maxSide, maxSide > 0 else { return image }
        let scale = maxSide / maxCurrentSide
        let newSize = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }


    private func mapPlateAnalysis(_ analysis: BackendPlateAnalysis) -> PlateAnalysis {
        let insights = analysis.insights.map { insight in
            let type: Insight.InsightType
            switch insight.type.lowercased() {
            case "positive":
                type = .positive
            case "warning":
                type = .warning
            default:
                type = .suggestion
            }
            return Insight(type: type, title: insight.title, description: insight.description)
        }

        let microModel: Micronutrients? = {
            guard let micros = analysis.micronutrients else { return nil }
            return Micronutrients(
                fiberG: micros.fiberG,
                vitaminCMg: micros.vitaminCMg,
                ironMg: micros.ironMg,
                other: micros.other
            )
        }()

        return PlateAnalysis(
            nutritionScore: analysis.nutritionScore,
            description: analysis.description,
            macronutrients: Macronutrients(
                protein: analysis.macronutrients.protein,
                carbs: analysis.macronutrients.carbs,
                fat: analysis.macronutrients.fat,
                calories: analysis.macronutrients.calories
            ),
            ingredients: analysis.ingredients.map { Ingredient(name: $0.name, amount: $0.amount) },
            insights: insights,
            micronutrients: microModel,
            connections: analysis.connections
        )
    }

    private func update(history: PlateAnalysisHistory, with analysis: PlateAnalysis) {
        history.name = analysis.description
        history.nutritionScore = analysis.nutritionScore
        history.analysisDescription = analysis.description
        history.protein = analysis.macronutrients.protein
        history.carbs = analysis.macronutrients.carbs
        history.fat = analysis.macronutrients.fat
        history.calories = analysis.macronutrients.calories

        let updatedIngredients = analysis.ingredients.map { PlateIngredient(name: $0.name, amount: $0.amount) }
        let updatedInsights: [PlateInsight] = analysis.insights.map { insight in
            let type: PlateInsight.PlateInsightType
            switch insight.type {
            case .positive: type = .positive
            case .suggestion: type = .suggestion
            case .warning: type = .warning
            }
            return PlateInsight(type: type, title: insight.title, description: insight.description)
        }
        history.ingredientsData = (try? JSONEncoder().encode(updatedIngredients)) ?? Data()
        history.insightsData = (try? JSONEncoder().encode(updatedInsights)) ?? Data()
        history.ingredientEntities = updatedIngredients.enumerated().map { idx, item in
            PlateIngredientEntity(name: item.name, amount: item.amount, order: idx)
        }
        history.insightEntities = updatedInsights.enumerated().map { idx, item in
            PlateInsightEntity(typeRawValue: item.type.rawValue, title: item.title, detail: item.description, order: idx)
        }
        if let micronutrients = analysis.micronutrients {
            history.microsData = try? JSONEncoder().encode(micronutrients)
        }
        if let connections = analysis.connections {
            history.connectionsData = try? JSONEncoder().encode(connections)
        }
    }

    private var lastAnalysisImageURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LastAnalysis", isDirectory: true)
        return cacheDir.appendingPathComponent("last-analysis.jpg")
    }

    private func persistLastAnalyzedImageToDisk(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.4) else { return }
        let url = lastAnalysisImageURL
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.set(url.path, forKey: lastAnalysisImagePathKey)
        } catch {
            AppLog.error(AppLog.storage, "Failed to persist last analysis image: \(error.localizedDescription)")
        }
    }
}
