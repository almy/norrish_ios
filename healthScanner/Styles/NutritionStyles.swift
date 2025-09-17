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
        case "A": return .green
        case "B": return Color.green.opacity(0.7)
        case "C": return .yellow
        case "D": return .orange
        case "E": return .red
        default: return .gray
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