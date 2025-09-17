import SwiftUI

// MARK: - Color Extensions
extension Color {
    static let primaryBackground = Color("Primary")

    // Adaptive colors for light/dark mode
    static let cardBackground = Color(.systemBackground)
    static let secondaryCardBackground = Color(.secondarySystemBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)

    // Custom semantic colors
    static let appAccent = Color.mint
    static let appSecondaryAccent = Color.green

    // Background colors
    static let primaryBg = Color(.systemBackground)
    static let secondaryBg = Color(.secondarySystemBackground)
    static let tertiaryBg = Color(.tertiarySystemBackground)

    // Border and separator colors
    static let separatorColor = Color(.separator)
    static let borderColor = Color(.separator)
}

// MARK: - Font Styles
struct AppFonts {
    static let title = Font.largeTitle.bold()
    static let heading = Font.title2.weight(.semibold)
    static let body = Font.body
    static let caption = Font.caption
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.3) : .gray.opacity(0.2),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.body.bold())
            .foregroundColor(.white)
            .padding()
            .background(Color.appAccent)
            .cornerRadius(8)
    }
}

struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.body.bold())
            .foregroundColor(Color.appAccent)
            .padding()
            .background(Color.secondaryCardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appAccent, lineWidth: 1)
            )
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