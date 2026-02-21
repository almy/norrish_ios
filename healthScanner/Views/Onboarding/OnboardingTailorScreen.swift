import SwiftUI

struct OnboardingTailorScreen: View {
    @Binding var needs: Set<String>
    @Binding var focus: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onCompleteProfile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeaderView(
                showBack: true,
                showSkip: false,
                currentStep: currentStep,
                totalSteps: totalSteps,
                onBack: onBack,
                onSkip: {}
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Tailor your\nJourney")
                    .font(AppFonts.serif(32, weight: .bold))
                    .foregroundColor(.midnightSpruce)
                Text("Set your baseline preferences. Norrish adapts its insights to match your nutritional goals.")
                    .font(AppFonts.sans(13, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Dietary Needs")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                OnboardingChipWrap {
                    ForEach(["Dairy Free", "Gluten Free", "Plant Based", "Paleo", "Keto"], id: \.self) { item in
                        OnboardingChip(label: item, isSelected: needs.contains(item)) {
                            if needs.contains(item) {
                                needs.remove(item)
                            } else {
                                needs.insert(item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Primary Focus")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                OnboardingChipWrap {
                    ForEach(["Weight Loss", "Clean Eating", "Muscle Gain"], id: \.self) { item in
                        OnboardingChip(label: item, isSelected: focus == item) {
                            focus = item
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)

            Text("Based on these choices, we'll prioritize plant-based protein alternatives and low-lactose products in your scan results.")
                .font(AppFonts.serif(13, weight: .regular))
                .italic()
                .foregroundColor(.mossInsight.opacity(0.8))
                .lineSpacing(4)
                .padding(.horizontal, 26)
                .padding(.top, 24)

            Spacer()
            OnboardingPrimaryButton("Complete Profile", icon: "checkmark.circle.fill", tint: .mossInsight, action: onCompleteProfile)
                .padding(.horizontal, 26)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingTailorScreen(
        needs: .constant(["Dairy Free", "Plant Based"]),
        focus: .constant("Clean Eating"),
        currentStep: 6,
        totalSteps: 7,
        onBack: {},
        onCompleteProfile: {}
    )
}
