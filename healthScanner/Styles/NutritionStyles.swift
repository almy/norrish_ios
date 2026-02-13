import SwiftUI

// MARK: - Nutrition-specific Styling
struct NutritionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct NutriScoreStyle: ViewModifier {
    let score: String

    func body(content: Content) -> some View {
        content
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(nutriScoreColor(for: score))
            .clipShape(Circle())
    }

    private func nutriScoreColor(for score: String) -> Color {
        switch score.uppercased() {
        case "A": return .mossInsight
        case "B": return Color.mossInsight.opacity(0.7)
        case "C": return .momentumAmber
        case "D": return .nordicSlate
        case "E": return .midnightSpruce
        default: return .nordicSlate
        }
    }
}

// MARK: - View Extensions
extension View {
    func nutritionCardStyle() -> some View {
        modifier(NutritionCardStyle())
    }

    func nutriScoreStyle(score: String) -> some View {
        modifier(NutriScoreStyle(score: score))
    }
}
