import SwiftUI

// MARK: - Design System Colors
extension Color {
    static let nordicBone = Color(red: 0.976, green: 0.969, blue: 0.949)
    static let midnightSpruce = Color(red: 0.106, green: 0.169, blue: 0.129)
    static let mossInsight = Color(red: 0.310, green: 0.475, blue: 0.259)
    static let nordicSlate = Color(red: 0.290, green: 0.365, blue: 0.400)
    static let momentumAmber = Color(red: 0.851, green: 0.466, blue: 0.024)

    static let cardSurface = Color.white
    static let cardBorder = Color.black.opacity(0.05)
    static let softDivider = Color.black.opacity(0.06)
    static let accentGlow = Color.momentumAmber.opacity(0.15)

    // Legacy aliases
    static let cardBackground = Color.cardSurface
    static let secondaryCardBackground = Color.nordicBone
    static let textPrimary = Color.midnightSpruce
    static let textSecondary = Color.nordicSlate
    static let tertiaryText = Color.nordicSlate.opacity(0.7)
    static let appAccent = Color.momentumAmber
    static let appSecondaryAccent = Color.mossInsight
    static let primaryBg = Color.nordicBone
    static let secondaryBg = Color.cardSurface
    static let tertiaryBg = Color.nordicBone
    static let separatorColor = Color.softDivider
    static let borderColor = Color.cardBorder
}

// MARK: - Typography
struct AppFonts {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold: name = "PlayfairDisplay-Bold"
        case .semibold: name = "PlayfairDisplay-SemiBold"
        default: name = "PlayfairDisplay-Regular"
        }
        return Font.custom(name, size: size)
    }

    static func serifItalic(_ size: CGFloat) -> Font {
        Font.custom("PlayfairDisplay-Italic", size: size)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold: name = "Inter28pt-Bold"
        case .semibold: name = "Inter28pt-SemiBold"
        case .medium: name = "Inter28pt-Medium"
        default: name = "Inter28pt-Regular"
        }
        return Font.custom(name, size: size)
    }

    static let display = serif(36, weight: .bold)
    static let title = serif(26, weight: .bold)
    static let heading = serif(20, weight: .semibold)
    static let body = sans(14, weight: .regular)
    static let bodyStrong = sans(14, weight: .semibold)
    static let caption = sans(12, weight: .regular)
    static let label = sans(10, weight: .bold)
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.sans(13, weight: .semibold))
            .foregroundColor(Color.nordicBone)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(
                Capsule().fill(Color.midnightSpruce)
            )
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.sans(13, weight: .medium))
            .foregroundColor(Color.momentumAmber)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(Color.clear)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func primaryButtonStyle() -> some View {
        modifier(PrimaryButtonStyle())
    }

    func secondaryButtonStyle() -> some View {
        modifier(SecondaryButtonStyle())
    }
}
