import SwiftUI
import UIKit

struct OnboardingHeaderView: View {
    let showBack: Bool
    let showSkip: Bool
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack {
            if showBack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.nordicSlate)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()
            OnboardingProgressDotsView(currentStep: currentStep, totalSteps: totalSteps)
            Spacer()

            if showSkip {
                Button("Skip", action: onSkip)
                    .font(AppFonts.sans(13, weight: .medium))
                    .foregroundColor(.nordicSlate.opacity(0.7))
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct OnboardingProgressDotsView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...totalSteps, id: \.self) { idx in
                Capsule()
                    .fill(dotColor(for: idx))
                    .frame(width: 24, height: 4)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < currentStep { return Color.mossInsight.opacity(0.4) }
        if index == currentStep { return Color.midnightSpruce }
        return Color.cardBorder
    }
}

struct OnboardingTitleBodyView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(AppFonts.serif(32, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .multilineTextAlignment(.center)
            Text(bodyText)
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 30)
        }
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let icon: String?
    let tint: Color
    let action: () -> Void

    init(_ title: String, icon: String? = nil, tint: Color = .midnightSpruce, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.sans(14, weight: .semibold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundColor(.nordicBone)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(tint)
            .clipShape(Capsule())
        }
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.sans(14, weight: .semibold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.midnightSpruce)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
        }
    }
}

struct OnboardingTrendCardView: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint)
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(AppFonts.sans(10, weight: .bold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
            }
            Spacer()
            Text(value)
                .font(AppFonts.serif(20, weight: .medium))
                .foregroundColor(.midnightSpruce)
        }
        .padding(12)
        .frame(width: 136, height: 180)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
    }
}

struct OnboardingFeatureRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.sans(13, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Text(subtitle)
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
            Spacer()
        }
    }
}

struct OnboardingChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFonts.sans(12, weight: .semibold))
                .foregroundColor(isSelected ? .midnightSpruce : .nordicSlate)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Color.mossInsight.opacity(0.16) : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.mossInsight.opacity(0.5) : Color.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingChipWrap<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        OnboardingFlowLayoutContainer(spacing: spacing) { content() }
    }
}

struct OnboardingFlowLayoutContainer: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? CGFloat.infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
