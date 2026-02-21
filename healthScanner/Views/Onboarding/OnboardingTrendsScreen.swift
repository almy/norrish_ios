import SwiftUI

struct OnboardingTrendsScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeaderView(
                showBack: false,
                showSkip: true,
                currentStep: currentStep,
                totalSteps: totalSteps,
                onBack: {},
                onSkip: onSkip
            )
            Spacer(minLength: 8)

            ZStack {
                OnboardingTrendCardView(title: "Hydro", value: "2.4L", tint: .blue.opacity(0.20))
                    .rotationEffect(.degrees(-10))
                    .offset(x: -92, y: 8)
                OnboardingTrendCardView(title: "Protein", value: "112g", tint: .pink.opacity(0.20))
                    .rotationEffect(.degrees(10))
                    .offset(x: 92, y: 8)
                OnboardingTrendCardView(title: "Fiber", value: "+12%", tint: .green.opacity(0.20))
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
            }
            .frame(height: 250)

            OnboardingTitleBodyView(
                title: "Evolve with\nyour Trends",
                bodyText: "We replace rigid targets with adaptive personal patterns that grow with you."
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
    OnboardingTrendsScreen(
        currentStep: 2,
        totalSteps: 7,
        onNext: {},
        onSkip: {}
    )
}
