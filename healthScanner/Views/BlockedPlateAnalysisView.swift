import SwiftUI
import UIKit

struct BlockedPlateAnalysisView: View {
    let analysis: PlateAnalysis
    let image: UIImage?
    let onRetake: () -> Void
    let onClose: () -> Void

    private var blockedReason: String {
        if let warning = analysis.insights.first(where: { $0.type == .warning }) {
            return warning.description
        }
        return "This image was blocked by safety guardrails and was not analyzed."
    }

    var body: some View {
        ZStack {
            Color.nordicBone.ignoresSafeArea()
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(18)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundColor(.momentumAmber)
                        Text("Analysis Blocked")
                            .font(AppFonts.serif(22, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                    }
                    Text(blockedReason)
                        .font(AppFonts.sans(13, weight: .regular))
                        .foregroundColor(.nordicSlate)
                    Text("Retake with only food in frame and avoid unrelated text or objects.")
                        .font(AppFonts.sans(12, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cardSurface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
                )

                Button(action: onRetake) {
                    Label("Try Another Photo", systemImage: "camera.viewfinder")
                        .font(AppFonts.sans(13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.midnightSpruce)
                        .cornerRadius(14)
                }

                Button(action: onClose) {
                    Text("Close")
                        .font(AppFonts.sans(13, weight: .medium))
                        .foregroundColor(.momentumAmber)
                }
            }
            .padding(20)
        }
    }
}

// Preview-only: mocked blocked analysis payload.
#Preview("Blocked Analysis") {
    BlockedPlateAnalysisView(
        analysis: PlateAnalysis(
            nutritionScore: 0,
            description: "Analysis blocked",
            macronutrients: Macronutrients(protein: 0, carbs: 0, fat: 0, calories: 0),
            ingredients: [],
            insights: [
                Insight(
                    type: .warning,
                    title: "Unsupported image",
                    description: "This image was blocked by safety guardrails and was not analyzed."
                )
            ],
            micronutrients: nil,
            connections: nil
        ),
        image: nil,
        onRetake: {},
        onClose: {}
    )
}
