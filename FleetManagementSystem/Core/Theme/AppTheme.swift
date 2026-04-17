import SwiftUI

// MARK: - Fleet Management System Design Tokens
// Dark-green + white palette following Apple Human Interface Guidelines

enum AppTheme {

    // MARK: Accent & Brand
    static let primaryGreen   = Color(red: 0.10, green: 0.48, blue: 0.24) // #1A7A3D
    static let darkGreen      = Color(red: 0.05, green: 0.36, blue: 0.18) // #0D5C2E
    static let lightGreen     = Color(red: 0.91, green: 0.96, blue: 0.92) // #E8F5EB
    static let mintGreen      = Color(red: 0.78, green: 0.93, blue: 0.82) // #C7EDD1

    // MARK: Status
    static let statusActive   = Color(red: 0.10, green: 0.48, blue: 0.24)
    static let statusWarning  = Color(red: 0.95, green: 0.68, blue: 0.14) // #F2AD24
    static let statusDanger   = Color(red: 0.90, green: 0.22, blue: 0.21) // #E63835
    static let statusInfo     = Color(red: 0.20, green: 0.49, blue: 0.96) // #337DF5

    // MARK: Neutrals
    static let cardBackground = Color(.systemBackground)
    static let pageBackground = Color(.systemGroupedBackground)
    static let secondaryCard  = Color(.secondarySystemGroupedBackground)
    static let separator      = Color(.separator)

    // MARK: Typography helpers
    static func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: Corner Radii
    static let cornerRadius: CGFloat      = 12
    static let smallCornerRadius: CGFloat  = 8
    static let largeCornerRadius: CGFloat  = 16

    // MARK: Spacing
    static let paddingSmall: CGFloat  = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat  = 24

    // MARK: Card shadow
    static let cardShadowColor  = Color.black.opacity(0.03)
    static let cardShadowRadius: CGFloat = 4
    static let cardShadowY: CGFloat      = 2
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(AppTheme.primaryGreen)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.primaryGreen)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(AppTheme.lightGreen)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
