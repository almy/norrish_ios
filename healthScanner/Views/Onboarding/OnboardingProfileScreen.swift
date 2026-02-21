import SwiftUI
import UIKit

struct OnboardingProfileScreen: View {
    @Binding var nameDraft: String
    @Binding var exclusions: Set<String>
    @Binding var needs: Set<String>
    @Binding var focus: String
    let avatarImage: UIImage?
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onAvatarTap: () -> Void
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

            Text("Create Your Profile")
                .font(AppFonts.serif(24, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            Button(action: onAvatarTap) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.cardSurface)
                        .frame(width: 96, height: 96)
                        .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
                        .overlay(
                            Group {
                                if let avatarImage {
                                    Image(uiImage: avatarImage)
                                        .resizable()
                                        .scaledToFill()
                                } else if let bundledAvatar = UIImage(named: "profile_avatar") {
                                    Image(uiImage: bundledAvatar)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person")
                                        .font(.system(size: 34))
                                        .foregroundColor(.nordicSlate)
                                }
                            }
                            .clipShape(Circle())
                        )

                    Circle()
                        .fill(Color.midnightSpruce)
                        .frame(width: 26, height: 26)
                        .overlay(Image(systemName: "camera.fill").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Full Name")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                TextField("e.g. Eleanor Vane", text: $nameDraft)
                    .font(AppFonts.sans(14, weight: .medium))
                    .foregroundColor(.midnightSpruce)
                    .tint(.midnightSpruce)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 12) {
                Text("Exclusions")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                OnboardingChipWrap {
                    ForEach(["No Peanuts", "Low Sodium", "No Added Sugar", "Gluten Free", "Dairy Free"], id: \.self) { item in
                        OnboardingChip(label: item, isSelected: exclusions.contains(item)) {
                            if exclusions.contains(item) {
                                exclusions.remove(item)
                            } else {
                                exclusions.insert(item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text("Dietary Needs")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                OnboardingChipWrap {
                    ForEach(["Dairy Free", "Gluten Free", "Plant Based", "Vegetarian", "Pescatarian", "Paleo", "Keto", "Low Carb", "Halal", "Kosher"], id: \.self) { item in
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
            .padding(.top, 20)

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
                .padding(.top, 20)

            Spacer(minLength: 12)

            OnboardingPrimaryButton("Complete Profile", icon: "checkmark.circle.fill", action: onCompleteProfile)
                .padding(.horizontal, 26)
                .padding(.bottom, 12)

            Text("Secure & Private")
                .font(AppFonts.sans(10, weight: .medium))
                .foregroundColor(.nordicSlate.opacity(0.7))
                .textCase(.uppercase)
                .kerning(1.6)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingProfileScreen(
        nameDraft: .constant("Eleanor Vane"),
        exclusions: .constant(["Low Sodium", "No Peanuts"]),
        needs: .constant(["Dairy Free", "Plant Based"]),
        focus: .constant("Clean Eating"),
        avatarImage: nil,
        currentStep: 5,
        totalSteps: 6,
        onBack: {},
        onAvatarTap: {},
        onCompleteProfile: {}
    )
}
