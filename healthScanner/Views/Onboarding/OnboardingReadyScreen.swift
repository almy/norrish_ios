import SwiftUI

struct OnboardingReadyScreen: View {
    let onSnapMeal: () -> Void
    let onScanProduct: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            Circle()
                .fill(Color.mossInsight.opacity(0.16))
                .frame(width: 118, height: 118)
                .overlay(Circle().stroke(Color.mossInsight.opacity(0.3), lineWidth: 1))
                .overlay(Image(systemName: "checkmark").font(.system(size: 42, weight: .bold)).foregroundColor(.mossInsight))

            Text("You're Ready")
                .font(AppFonts.serif(34, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .padding(.top, 26)

            Text("Your first insight is one tap away. Start by scanning a meal or a product.")
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            VStack(spacing: 10) {
                OnboardingFeatureRowView(icon: "camera", title: "Meal Analysis", subtitle: "AI-powered nutrition breakdown", tint: .orange.opacity(0.2))
                Divider().background(Color.softDivider)
                OnboardingFeatureRowView(icon: "barcode.viewfinder", title: "Product Scanning", subtitle: "Swedish database with fallback", tint: .purple.opacity(0.2))
                Divider().background(Color.softDivider)
                OnboardingFeatureRowView(icon: "chart.line.uptrend.xyaxis", title: "Adaptive Trends", subtitle: "Patterns that evolve with you", tint: .green.opacity(0.2))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
            .padding(.horizontal, 26)
            .padding(.top, 24)

            Spacer()

            OnboardingPrimaryButton("Snap a Meal", icon: "camera", action: onSnapMeal)
                .padding(.horizontal, 26)

            OnboardingSecondaryButton("Scan a Product", icon: "barcode.viewfinder", action: onScanProduct)
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 30)
        }
    }
}

#Preview {
    OnboardingReadyScreen(
        onSnapMeal: {},
        onScanProduct: {}
    )
}
