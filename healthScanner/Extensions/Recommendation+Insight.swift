import Foundation
import SwiftUI

// Bridges engine recommendations to the existing insights UI model.
extension NutritionRecommendation {
    func asPersonalizedInsight() -> PersonalizedInsight {
        let (icon, color): (String, Color) = {
            switch type {
            case .deficiencyCorrection: return ("leaf.fill", .mossInsight)
            case .swapSuggestion: return ("arrow.2.squarepath", .midnightSpruce)
            case .riskAlert: return ("exclamationmark.triangle.fill", .momentumAmber)
            case .habitPattern: return ("clock.fill", .nordicSlate)
            case .synergyPairing: return ("link", .mossInsight)
            case .hydration: return ("drop.fill", .mossInsight)
            case .categoryExploration: return ("sparkles", .momentumAmber)
            case .correlationInsight: return ("chart.line.uptrend.xyaxis", .nordicSlate)
            case .recommendation: return ("lightbulb.fill", .momentumAmber)
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
