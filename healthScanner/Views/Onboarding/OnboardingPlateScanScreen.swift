import SwiftUI

struct OnboardingPlateScanScreen: View {
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
                Group {
                    if let heroImage = UIImage(named: "onboarding_hero") {
                        Image(uiImage: heroImage)
                            .resizable()
                            .scaledToFill()
                            .offset(x: -18)
                    } else {
                        Color.black.opacity(0.7)
                    }
                }
                .frame(height: 332)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                Circle()
                    .stroke(Color.white.opacity(0.42), lineWidth: 2)
                    .frame(width: 190, height: 190)
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1).scaleEffect(1.08))

                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Analyzing nutrients...")
                        .font(AppFonts.sans(11, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(y: 122)
            }
            .padding(.horizontal, 26)

            OnboardingTitleBodyView(
                title: "Snap your\nPlate",
                bodyText: "Point, capture, and understand what's on your plate. AI reveals the nutrition story instantly."
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
    OnboardingPlateScanScreen(
        currentStep: 3,
        totalSteps: 7,
        onBack: {},
        onNext: {},
        onSkip: {}
    )
}
