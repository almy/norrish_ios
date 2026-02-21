import SwiftUI

struct OnboardingProductScanScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeaderView(
                showBack: true,
                showSkip: true,
                currentStep: currentStep,
                totalSteps: totalSteps,
                onBack: onBack,
                onSkip: onSkip
            )
            Spacer(minLength: 12)

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.92, blue: 0.89), Color(red: 0.91, green: 0.89, blue: 0.86)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(height: 332)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 120, height: 162)
                    .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "leaf")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.mossInsight)
                            Text("Organic Oats")
                                .font(AppFonts.sans(9, weight: .semibold))
                                .foregroundColor(.nordicSlate)
                                .textCase(.uppercase)
                            Rectangle()
                                .fill(Color.midnightSpruce)
                                .frame(height: 2)
                                .padding(.horizontal, 18)
                        }
                    )

                Rectangle()
                    .fill(LinearGradient(colors: [Color.clear, Color.primary, Color.clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .padding(.horizontal, 26)

                HStack(spacing: 10) {
                    Text("A")
                        .font(AppFonts.sans(13, weight: .bold))
                        .foregroundColor(.mossInsight)
                        .frame(width: 24, height: 24)
                        .background(Color.mossInsight.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nutri-Score A")
                            .font(AppFonts.sans(12, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                        Text("340 kcal · 12g protein · 8g fiber")
                            .font(AppFonts.sans(10, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(y: 123)
            }
            .padding(.horizontal, 26)

            OnboardingTitleBodyView(
                title: "Scan any\nProduct",
                bodyText: "Scan the barcode, skip the fine print. Instant nutrition data from Swedish databases."
            )
            .padding(.top, 20)

            Spacer()
            OnboardingPrimaryButton("Next", icon: "arrow.right", action: onNext)
                .padding(.horizontal, 26)
                .padding(.bottom, 34)
        }
    }
}

#Preview {
    OnboardingProductScanScreen(
        currentStep: 4,
        totalSteps: 7,
        onBack: {},
        onNext: {},
        onSkip: {}
    )
}
