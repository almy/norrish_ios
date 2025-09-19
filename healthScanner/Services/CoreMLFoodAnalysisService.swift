//
//  CoreMLFoodAnalysisService.swift
//  healthScanner
//
//  CoreML-based food classification and segmentation service
//

import Foundation
import CoreML
import Vision
import UIKit
import CoreImage
import AVFoundation

// MARK: - Food Analysis Results
struct FoodClassificationResult {
    let label: String
    let confidence: Float
    let allPredictions: [(label: String, confidence: Float)]
}

struct FoodSegmentationResult {
    let segmentationMask: CVPixelBuffer?
    let detectedRegions: [FoodRegion]
    let totalFoodPixels: Int
    let imageSize: CGSize
}

struct FoodRegion {
    let boundingBox: CGRect
    let pixelCount: Int
    let centerPoint: CGPoint
    let confidence: Float
}

struct EnhancedFoodAnalysisResult {
    let classification: FoodClassificationResult?
    let segmentation: FoodSegmentationResult?
    let processingTime: TimeInterval
    let isSuccessful: Bool
}

// MARK: - Model Manager
final class CoreMLFoodAnalysisService: ObservableObject {
    static let shared = CoreMLFoodAnalysisService()

    @Published var isReady = false
    @Published var modelStatus: String = "ai.status.loading".localized

    private var classificationModel: MLModel?
    private var segmentationModel: MLModel?
    private var isInitialized = false

    // Model info
    private let classificationModelName = "Food101_Classification_fp16"
    private let segmentationModelName = "UECFoodPix_Seg_fp16"

    private init() {
        initializeModels()
    }

    // MARK: - Model Initialization

    private func initializeModels() {
        Task {
            await loadModels()
        }
    }

    @MainActor
    private func loadModels() async {
        print("🤖 Initializing CoreML food analysis models...")
        modelStatus = "ai.status.loading".localized

        await withTaskGroup(of: Void.self) { group in
            // Load classification model
            group.addTask { [weak self] in
                await self?.loadClassificationModel()
            }

            // Load segmentation model
            group.addTask { [weak self] in
                await self?.loadSegmentationModel()
            }
        }

        updateReadyStatus()
    }

    private func loadClassificationModel() async {
        print("🔍 Looking for classification model: \(classificationModelName)")

        // Debug: List all available .mlpackage resources
        if let modelPaths = Bundle.main.paths(forResourcesOfType: "mlpackage", inDirectory: nil) {
            print("📦 Available .mlpackage files in bundle:")
            for path in modelPaths {
                print("  - \(URL(fileURLWithPath: path).lastPathComponent)")
            }
        }

        guard let modelURL = Bundle.main.url(forResource: classificationModelName, withExtension: "mlpackage") else {
            print("❌ Classification model not found: \(classificationModelName)")
            print("🔍 Trying alternative path lookup...")

            // Try alternative path in CoreML directory
            if let altURL = Bundle.main.url(forResource: classificationModelName, withExtension: "mlpackage", subdirectory: "CoreML") {
                print("✅ Found classification model in CoreML subdirectory")
                await loadModel(at: altURL, isClassification: true)
                return
            }

            print("❌ Classification model not found in any location")
            return
        }

        await loadModel(at: modelURL, isClassification: true)
    }

    private func loadModel(at url: URL, isClassification: Bool) async {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all

            let model = try MLModel(contentsOf: url, configuration: config)

            if isClassification {
                classificationModel = model
                print("✅ Classification model loaded successfully from: \(url.lastPathComponent)")
            } else {
                segmentationModel = model
                print("✅ Segmentation model loaded successfully from: \(url.lastPathComponent)")
            }
        } catch {
            let modelType = isClassification ? "classification" : "segmentation"
            print("❌ Failed to load \(modelType) model: \(error)")
        }
    }

    private func loadSegmentationModel() async {
        print("🔍 Looking for segmentation model: \(segmentationModelName)")

        guard let modelURL = Bundle.main.url(forResource: segmentationModelName, withExtension: "mlpackage") else {
            print("❌ Segmentation model not found: \(segmentationModelName)")
            print("🔍 Trying alternative path lookup...")

            // Try alternative path in CoreML directory
            if let altURL = Bundle.main.url(forResource: segmentationModelName, withExtension: "mlpackage", subdirectory: "CoreML") {
                print("✅ Found segmentation model in CoreML subdirectory")
                await loadModel(at: altURL, isClassification: false)
                return
            }

            print("❌ Segmentation model not found in any location")
            return
        }

        await loadModel(at: modelURL, isClassification: false)
    }

    @MainActor
    private func updateReadyStatus() {
        let hasClassification = classificationModel != nil
        let hasSegmentation = segmentationModel != nil

        isReady = hasClassification || hasSegmentation
        isInitialized = true

        if hasClassification && hasSegmentation {
            modelStatus = "ai.classification.full".localized
        } else if hasClassification {
            modelStatus = "ai.classification.recognition_only".localized
        } else if hasSegmentation {
            modelStatus = "ai.segmentation.volume_only".localized
        } else {
            modelStatus = "ai.status.not_available".localized
            // Don't block the UI even if models aren't found
            isReady = true  // Allow camera to work without CoreML
        }

        print("🤖 CoreML models ready: \(modelStatus)")
    }

    // MARK: - Public Analysis Methods

    func analyzeFood(image: UIImage) async -> EnhancedFoodAnalysisResult {
        // Don't block if models aren't initialized - return graceful fallback
        if !isInitialized {
            print("⚠️ Models not initialized yet - returning fallback result")
            return EnhancedFoodAnalysisResult(
                classification: nil,
                segmentation: nil,
                processingTime: 0,
                isSuccessful: true  // Still allow the OpenAI analysis to proceed
            )
        }

        let startTime = Date()

        // Prepare image for analysis
        guard let processedImage = preprocessImage(image) else {
            print("❌ Failed to preprocess image for analysis")
            return EnhancedFoodAnalysisResult(
                classification: nil,
                segmentation: nil,
                processingTime: 0,
                isSuccessful: false
            )
        }

        // Safely attempt CoreML inference - don't fail if models aren't available
        var classification: FoodClassificationResult? = nil
        var segmentation: FoodSegmentationResult? = nil

        if classificationModel != nil {
            classification = performClassification(on: processedImage)
        }

        if segmentationModel != nil {
            segmentation = performSegmentation(on: processedImage, originalSize: image.size)
        }

        let processingTime = Date().timeIntervalSince(startTime)

        print("🎯 Food analysis completed in \(String(format: "%.3f", processingTime))s")

        return EnhancedFoodAnalysisResult(
            classification: classification,
            segmentation: segmentation,
            processingTime: processingTime,
            isSuccessful: true  // Always successful - OpenAI can proceed without CoreML
        )
    }

    // MARK: - Image Preprocessing

    private func preprocessImage(_ image: UIImage) -> CVPixelBuffer? {
        // Convert UIImage to CVPixelBuffer for model input
        let targetSize = CGSize(width: 224, height: 224) // Standard input size for most models

        guard let resizedImage = image.resized(to: targetSize),
              let cgImage = resizedImage.cgImage else {
            return nil
        }

        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(targetSize.width),
            Int(targetSize.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        context?.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        return buffer
    }

    // MARK: - Classification

    private func performClassification(on pixelBuffer: CVPixelBuffer) -> FoodClassificationResult? {
        guard let model = classificationModel else {
            print("⚠️ Classification model not available")
            return nil
        }

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
            let prediction = try model.prediction(from: input)

            // Extract classification results - try different output names
            let outputNames = ["classLabelProbs", "output", "predictions", "scores"]

            for outputName in outputNames {
                if let classLabelProbs = prediction.featureValue(for: outputName)?.dictionaryValue as? [String: Double] {
                    let sortedPredictions = classLabelProbs.sorted { $0.value > $1.value }
                    let topPrediction = sortedPredictions.first

                    let allPredictions = sortedPredictions.prefix(5).map { (label: $0.key, confidence: Float($0.value)) }

                    return FoodClassificationResult(
                        label: topPrediction?.key ?? "Unknown",
                        confidence: Float(topPrediction?.value ?? 0.0),
                        allPredictions: allPredictions
                    )
                }
            }

            // If no dictionary output found, try other formats
            print("🔍 Available outputs: \(prediction.featureNames)")
        } catch {
            print("❌ Classification inference error: \(error)")
        }

        return nil
    }

    // MARK: - Segmentation

    private func performSegmentation(on pixelBuffer: CVPixelBuffer, originalSize: CGSize) -> FoodSegmentationResult? {
        guard let model = segmentationModel else {
            print("⚠️ Segmentation model not available")
            return nil
        }

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
            let prediction = try model.prediction(from: input)

            // Extract segmentation mask - try different output names
            let segmentationOutputNames = ["semanticPredictions", "output", "segmentation", "mask"]

            for outputName in segmentationOutputNames {
                if let segmentationOutput = prediction.featureValue(for: outputName)?.multiArrayValue {
                    let mask = try convertMultiArrayToPixelBuffer(segmentationOutput)
                    let regions = analyzeSegmentationMask(mask, originalSize: originalSize)

                    return FoodSegmentationResult(
                        segmentationMask: mask,
                        detectedRegions: regions.regions,
                        totalFoodPixels: regions.totalPixels,
                        imageSize: originalSize
                    )
                }
            }

            print("🔍 Available segmentation outputs: \(prediction.featureNames)")
        } catch {
            print("❌ Segmentation inference error: \(error)")
        }

        return nil
    }

    private func convertMultiArrayToPixelBuffer(_ multiArray: MLMultiArray) throws -> CVPixelBuffer? {
        let width = multiArray.shape[2].intValue
        let height = multiArray.shape[1].intValue

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        let baseAddress = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let value = multiArray[index].doubleValue
                baseAddress?[index] = UInt8(max(0, min(255, value * 255)))
            }
        }

        return buffer
    }

    private func analyzeSegmentationMask(_ mask: CVPixelBuffer?, originalSize: CGSize) -> (regions: [FoodRegion], totalPixels: Int) {
        guard let mask = mask else {
            return (regions: [], totalPixels: 0)
        }

        // Simplified region analysis
        // In a full implementation, you would use connected component analysis
        // to identify distinct food regions

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let baseAddress = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self)

        var totalFoodPixels = 0
        var regions: [FoodRegion] = []

        // Count total food pixels (threshold > 128 for food vs background)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if let pixel = baseAddress?[index], pixel > 128 {
                    totalFoodPixels += 1
                }
            }
        }

        // Create a simplified region for the detected food area
        if totalFoodPixels > 100 { // Minimum threshold
            let centerX = originalSize.width / 2
            let centerY = originalSize.height / 2
            let estimatedWidth = originalSize.width * 0.6
            let estimatedHeight = originalSize.height * 0.6

            let region = FoodRegion(
                boundingBox: CGRect(
                    x: centerX - estimatedWidth/2,
                    y: centerY - estimatedHeight/2,
                    width: estimatedWidth,
                    height: estimatedHeight
                ),
                pixelCount: totalFoodPixels,
                centerPoint: CGPoint(x: centerX, y: centerY),
                confidence: min(1.0, Float(totalFoodPixels) / Float(width * height))
            )
            regions.append(region)
        }

        return (regions: regions, totalPixels: totalFoodPixels)
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}