import Foundation
import SwiftUI

// Bridges engine recommendations to the existing insights UI model.
extension NutritionRecommendation {
    func asPersonalizedInsight() -> PersonalizedInsight {
        let (icon, color): (String, Color) = {
            switch type {
            case .deficiencyCorrection: return ("leaf.fill", .green)
            case .swapSuggestion: return ("arrow.2.squarepath", .blue)
            case .riskAlert: return ("exclamationmark.triangle.fill", .orange)
            case .habitPattern: return ("clock.fill", .purple)
            case .synergyPairing: return ("link", .teal)
            case .hydration: return ("drop.fill", .cyan)
            case .categoryExploration: return ("sparkles", .yellow)
            case .correlationInsight: return ("chart.line.uptrend.xyaxis", .indigo)
            }
        }()

        return PersonalizedInsight(
            icon: icon,
            iconColor: color,
            title: title,
            message: message,
            category: .recommendation,
            reason: reason,
            evidence: Array(evidence.prefix(3)),
            tags: tags
        )
    }
}
