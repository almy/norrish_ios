import SwiftUI

struct OnboardingMissionScreen: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            Text("Nourishment\nthrough Insight")
                .font(AppFonts.serif(32, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)

            Group {
                if let heroImage = UIImage(named: "onboarding_hero") {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(x: -18)
                } else {
                    Color.cardSurface
                }
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 26)
            .padding(.top, 22)

            Text("Norrish uses your camera to reveal the story behind every bite. No judgment, just intelligence.")
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.top, 22)

            Spacer()

            OnboardingPrimaryButton("Begin Discovery", action: onNext)
                .padding(.horizontal, 26)
                .padding(.bottom, 14)

            OnboardingProgressDotsView(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingMissionScreen(
        currentStep: 1,
        totalSteps: 7,
        onNext: {}
    )
}
