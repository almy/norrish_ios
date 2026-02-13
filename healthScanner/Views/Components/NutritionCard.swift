import SwiftUI

struct NutritionCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFonts.sans(10, weight: .bold))
                .foregroundColor(.nordicSlate)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(AppFonts.serif(20, weight: .bold))
                    .foregroundColor(color)
                
                Text(unit)
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}
