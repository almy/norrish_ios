// ARPlateScanNutrition.swift — Rewritten (Real Scanner Wrapper + Domain Models)
// Filename must remain ARPlateScanNutrition.swift
//
// Provides:
//  - ARPlateScanNutrition (result returned by the scanners)
//  - PlateAnalysis domain model + supporting types
//  - ARPlateScannerView SwiftUI wrapper that presents the real scanners:
//      * ARPlateScannerViewController (ARKit + sceneDepth on LiDAR devices)
//      * DualCameraPlateScannerViewController (AVCapture dual‑camera depth fallback)
//  - Simulator fallback UI that lets you simulate a scan
//
// Requirements:
//  - Keep the companion files in your target:
//      "AR Plate Scanner – Full Integration for PlateAnalysisView.swift"
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

// MARK: - PlateAnalysis Domain Model (used by views & history)
public struct PlateAnalysis: Codable, Equatable {
    public let nutritionScore: Double
    public let description: String
    public let macronutrients: Macronutrients
    public let ingredients: [Ingredient]
    public let insights: [Insight]
    public let micronutrients: Micronutrients?
    public let connections: [String]?

    public static func mockAnalysis() -> PlateAnalysis {
        PlateAnalysis(
            nutritionScore: 8.2,
            description: "Sample plate with balanced macros.",
            macronutrients: Macronutrients(protein: 25, carbs: 40, fat: 18, calories: 480),
            ingredients: [
                Ingredient(name: "Chicken Breast", amount: "120 g"),
                Ingredient(name: "Brown Rice", amount: "100 g")
            ],
            insights: [
                Insight(type: .positive, title: "Great Protein", description: "Adequate lean protein for muscle support."),
                Insight(type: .suggestion, title: "Add Greens", description: "Consider adding leafy vegetables for micronutrients.")
            ],
            micronutrients: Micronutrients(fiberG: 5, vitaminCMg: 20, ironMg: 2, other: "Likely contains potassium and magnesium"),
            connections: ["Olive oil adds vitamin E", "Whole grains contribute B vitamins"]
        )
    }
}

public struct Macronutrients: Codable, Equatable {
    public let protein: Int
    public let carbs: Int
    public let fat: Int
    public let calories: Int
}

public struct Ingredient: Codable, Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let amount: String

    private enum CodingKeys: String, CodingKey {
        case name, amount
    }
}

public struct Insight: Codable, Identifiable, Equatable {
    public enum InsightType: String, Codable { case positive, suggestion, warning }
    public let id = UUID()
    public let type: InsightType
    public let title: String
    public let description: String

    private enum CodingKeys: String, CodingKey {
        case type, title, description
    }
}

public struct Micronutrients: Codable, Equatable {
    public let fiberG: Int?
    public let vitaminCMg: Int?
    public let ironMg: Int?
    public let other: String?

    private enum CodingKeys: String, CodingKey {
        case fiberG = "fiberG"
        case vitaminCMg = "vitaminCMg"
        case ironMg = "ironMg"
        case other
    }
}

// MARK: - SwiftUI Wrapper presenting the REAL scanner(s)
// On devices with ARKit sceneDepth → presents ARPlateScannerViewController
// Otherwise → ARPlateScannerViewController auto‑presents DualCameraPlateScannerViewController
// In the Simulator → we show a small simulate UI so you can test end‑to‑end UI flows.

#if canImport(ARKit)
import ARKit

public struct ARPlateScannerView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = ARPlateScannerViewController

    public let onResult: (ARPlateScanNutrition, UIImage) -> Void
    public let onCancel: () -> Void

    public init(onResult: @escaping (ARPlateScanNutrition, UIImage) -> Void,
                onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> ARPlateScannerViewController {
        let vc = ARPlateScannerViewController()
        vc.onResult = { result, image in
            onResult(result, image)
        }
        vc.onCancel = { onCancel() }
        return vc
    }

    public func updateUIViewController(_ uiViewController: ARPlateScannerViewController, context: Context) { }
}

#else

// Simulator fallback keeps a minimal simulate flow so previews/tests work
public struct ARPlateScannerView: View {
    public let onResult: (ARPlateScanNutrition, UIImage) -> Void
    public let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSimulating = false

    public init(onResult: @escaping (ARPlateScanNutrition, UIImage) -> Void,
                onCancel: @escaping () -> Void) {
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 28) {
                Text("AR Plate Scanner").font(.title2).bold().foregroundColor(.white)
                Text("(Simulator – placeholder)").foregroundColor(.white.opacity(0.55)).font(.footnote)
                Spacer()
                if isSimulating {
                    ProgressView("Analyzing…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                } else {
                    Button(action: simulateScan) {
                        HStack { Image(systemName: "sparkles"); Text("Simulate Scan") }
                            .font(.headline).foregroundColor(.black)
                            .padding(.horizontal, 34).padding(.vertical, 14)
                            .background(Color.green).cornerRadius(28)
                    }
                }
                Button("Cancel", role: .cancel) { onCancel(); dismiss() }
                    .foregroundColor(.white).padding(.top, 8)
                Spacer()
            }
            .padding(.top, 50).padding(.bottom, 40)
        }
    }

    private func simulateScan() {
        isSimulating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let scan = ARPlateScanNutrition(
                label: "Pasta",
                confidence: 0.7,
                volumeML: 320,
                massG: 275,
                calories: 610,
                protein: 18,
                carbs: 85,
                fat: 14
            )
            let image = UIImage(systemName: "fork.knife")!.withTintColor(.white, renderingMode: .alwaysOriginal)
            onResult(scan, image)
            dismiss()
        }
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
