import SwiftUI

struct NutriScoreBadge: View {
    let letter: NutriScoreLetter
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Nutri-Score")
                .font(compact ? .caption2 : .caption)
                .foregroundColor(.secondary)
            Text(letter.rawValue)
                .font(compact ? .footnote.weight(.bold) : .subheadline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 6)
                .background(swiftUIColor(from: letter))
                .clipShape(Capsule())
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 4 : 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private func swiftUIColor(from letter: NutriScoreLetter) -> Color {
        let colorTuple = letter.color
        return Color(red: colorTuple.red, green: colorTuple.green, blue: colorTuple.blue)
    }
}

// All Nutri-Score calculation functions have been moved to NutriScoreUtilities.swift