//
//  EnhancedCameraPreviewView.swift
//  healthScanner
//
//  Enhanced camera preview with real-time CoreML food detection
//

import SwiftUI
import UIKit

struct EnhancedCameraPreviewView: View {
    let onImageCaptured: (UIImage) -> Void
    @StateObject private var coreMLService = CoreMLFoodAnalysisService.shared
    @State private var detectedFood: String?
    @State private var confidence: Float = 0.0
    @State private var capturedImage: UIImage?
    @State private var showAnalyzingOverlay = false
    @State private var showResultOverlay = false
    @State private var latestAnalysis: PlateAnalysis?
    @State private var analysisTask: Task<Void, Never>?
    @State private var analysisError: String?

    var body: some View {
        ZStack {
            CameraPreviewView(onImageCaptured: { image in
                // 1) Show analyzing overlay immediately
                capturedImage = image
                showAnalyzingOverlay = true
                latestAnalysis = nil
                analysisError = nil

                // 2) Kick off backend analysis
                analysisTask?.cancel()
                analysisTask = Task {
                    do {
                        let analysis = try await PlateAnalysisService.analyze(image: image)
                        await MainActor.run {
                            latestAnalysis = analysis
                            showAnalyzingOverlay = false
                            showResultOverlay = true
                        }
                    } catch is CancellationError {
                        // User dismissed analyzing overlay
                    } catch {
                        await MainActor.run {
                            analysisError = (error as? LocalizedError)?.errorDescription ?? "Failed to analyze plate."
                            showAnalyzingOverlay = false
                        }
                    }
                }

                // Forward to any parent listeners if needed
                onImageCaptured(image)
            })

            // AI Status Overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(coreMLService.isReady ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(coreMLService.isReady ? "ai.status.ready".localized : "ai.status.loading".localized)
                                .font(.caption)
                                .foregroundColor(.white)
                        }

                        if let food = detectedFood, !food.isEmpty {
                            Text(String(format: "ai.food_detected".localized, food))
                                .font(.caption)
                                .foregroundColor(.white)
                                .opacity(confidence > 0.3 ? 1.0 : 0.5)
                        }

                        if confidence > 0 {
                            Text(String(format: "analysis.confidence_score".localized, confidence * 100))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                Spacer()
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showAnalyzingOverlay, onDismiss: {
            // If dismissed manually, cancel the task
            analysisTask?.cancel()
        }) {
            AnalyzingOverlayView(
                message: analysisError == nil ? NSLocalizedString("Analyzing your plate…", comment: "Analyzing state") : (analysisError ?? "Error"),
                isError: analysisError != nil,
                onCancel: {
                    analysisTask?.cancel()
                    showAnalyzingOverlay = false
                },
                onRetry: {
                    guard let img = capturedImage else { return }
                    analysisError = nil
                    showAnalyzingOverlay = true
                    analysisTask?.cancel()
                    analysisTask = Task {
                        do {
                            let analysis = try await PlateAnalysisService.analyze(image: img)
                            await MainActor.run {
                                latestAnalysis = analysis
                                showAnalyzingOverlay = false
                                showResultOverlay = true
                            }
                        } catch is CancellationError {
                        } catch {
                            await MainActor.run {
                                analysisError = (error as? LocalizedError)?.errorDescription ?? "Failed to analyze plate."
                                showAnalyzingOverlay = true
                            }
                        }
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showResultOverlay) {
            PlateAnalysisResultView(
                analysis: latestAnalysis ?? PlateAnalysis.mockAnalysis(),
                image: capturedImage,
                onStartNewScan: {
                    showResultOverlay = false
                },
                onClose: {
                    analysisTask?.cancel()
                    showResultOverlay = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .mlDetectionUpdate)) { notification in
            if let userInfo = notification.userInfo,
               let foodName = userInfo["foodName"] as? String,
               let conf = userInfo["confidence"] as? Float {
                detectedFood = foodName
                confidence = conf
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let mlDetectionUpdate = Notification.Name("mlDetectionUpdate")
}

// MARK: - Enhanced Detection Integration
extension CoreMLFoodAnalysisService {
    func performRealtimeInference(on pixelBuffer: CVPixelBuffer) {
        // Convert to UIImage synchronously to avoid Sendable issues
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        let uiImage = UIImage(cgImage: cgImage)

        // Now run analysis asynchronously with the UIImage (which is Sendable)
        Task { @MainActor in
            let result = await analyzeFood(image: uiImage)

            if let classification = result.classification {
                NotificationCenter.default.post(
                    name: .mlDetectionUpdate,
                    object: nil,
                    userInfo: [
                        "foodName": classification.label,
                        "confidence": classification.confidence
                    ]
                )
            }
        }
    }
}

#Preview {
    EnhancedCameraPreviewView { _ in }
}
struct AnalyzingOverlayView: View {
    let message: String
    let isError: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 20) {
                if !isError {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.6)
                    Text(message)
                        .foregroundColor(.white)
                        .font(.headline)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 48))
                    Text(message)
                        .foregroundColor(.white)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button(action: onRetry) {
                            Text("Retry")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(24)
                        }
                        Button(action: onCancel) {
                            Text("Close")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(24)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

