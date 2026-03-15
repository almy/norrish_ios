// ARPlateScanNutrition.swift — Rewritten (Real Scanner Wrapper + Domain Models)
// Filename must remain ARPlateScanNutrition.swift
//
// Provides:
//  - ARPlateScanNutrition (result returned by the scanners)
//  - PlateAnalysis domain model + supporting types
//  - ARPlateScannerView SwiftUI wrapper that presents the real scanners:
//      * ARPlateScannerViewController (ARKit + sceneDepth on LiDAR devices)
//      * DualCameraPlateScannerViewController (AVCapture dual‑camera depth fallback)
//  - Simulator compile stub (active simulator flow is in PlateScanView)
//
// Requirements:
//  - Keep the companion files in your target:
//      "DualCameraPlateScanner (Non‑LiDAR Fallback) – AVCapture Depth Module"
//  - Info.plist: NSCameraUsageDescription

import Foundation
import SwiftUI
import UIKit

// MARK: - Raw AR Scan Nutrition Result (shared by both scanner paths)
public struct ARPlateScanNutrition: Equatable {
    public let label: String
    public let confidence: Float
    public let volumeML: Float   // milliliters
    public let massG: Float      // grams
    public let calories: Int
    public let protein: Int
    public let carbs: Int
    public let fat: Int

    public init(label: String,
                confidence: Float = 0.5,
                volumeML: Float,
                massG: Float,
                calories: Int,
                protein: Int,
                carbs: Int,
                fat: Int) {
        self.label = label
        self.confidence = confidence
        self.volumeML = volumeML
        self.massG = massG
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

// Note: PlateAnalysis, Macronutrients, Ingredient, Insight, and Micronutrients
// models are defined in Models/PlateAnalysis.swift to avoid duplication

// MARK: - SwiftUI Wrapper presenting the REAL scanner(s)
// On devices with ARKit sceneDepth → presents ARPlateScannerViewController
// Otherwise → ARPlateScannerViewController auto‑presents DualCameraPlateScannerViewController
// In the Simulator → compile stub only (active simulator flow uses PlateScanView fixture picker).

#if canImport(ARKit)
import ARKit

public struct ARPlateScannerView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = UIViewController

    public let onResult: (ARPlateScanNutrition, UIImage) -> Void
    public let onCancel: () -> Void

    public init(onResult: @escaping (ARPlateScanNutrition, UIImage) -> Void,
                onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        // Decide at wrapper level to avoid stacking controllers
        if ARWorldTrackingConfiguration.isSupported,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            // LiDAR path: use ARKit scanner
            let vc = ARPlateScannerViewController()
            vc.onResult = { result, image in
                onResult(result, image)
            }
            vc.onCancel = { onCancel() }
            return vc
        } else {
            // Non-LiDAR or AR not supported: use dual-camera fallback directly
            let fallback = DualCameraPlateScannerViewController()
            fallback.onResult = { result, image in
                onResult(result, image)
            }
            fallback.onCancel = { onCancel() }
            return fallback
        }
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

#else

// Simulator stub — the active simulator plate flow uses PlateScanView's
// fixture-backed path (ExternalPlateFixtureLoader / PhotoLibraryPickerView).
// This struct exists only so ARPlateScannerView compiles on simulator targets
// that cannot import ARKit. It is not presented in the current UI flow.
public struct ARPlateScannerView: View {
    public let onResult: (ARPlateScanNutrition, UIImage) -> Void
    public let onCancel: () -> Void

    public init(onResult: @escaping (ARPlateScanNutrition, UIImage) -> Void,
                onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public var body: some View {
        Color.clear.onAppear { onCancel() }
    }
}
#endif

// MARK: - Previews
#Preview {
    ARPlateScannerView { scan, img in
        print("Simulated scan:", scan.label, scan.volumeML, scan.calories)
    } onCancel: {}
    .preferredColorScheme(.dark)
}
