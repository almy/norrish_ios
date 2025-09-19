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

    var body: some View {
        ZStack {
            CameraPreviewView(onImageCaptured: onImageCaptured)

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