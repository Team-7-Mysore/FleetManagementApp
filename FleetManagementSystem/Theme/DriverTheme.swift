import SwiftUI

enum DriverTheme {
    static let background = Color.white
    static let surface = Color.white
    static let cardBackground = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let fieldBackground = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let subtleFill = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let subtleGreen = Color(red: 0.91, green: 0.97, blue: 0.92)
    static let accent = Color(red: 0.09, green: 0.64, blue: 0.29)
    static let primaryText = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let secondaryText = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let tertiaryText = Color(red: 0.58, green: 0.61, blue: 0.67)
    static let cardStroke = Color.black.opacity(0.05)
    static let shadowColor = Color.black.opacity(0.07)

    static let backgroundGradient = LinearGradient(
        colors: [Color.white, Color(red: 0.98, green: 0.99, blue: 0.98)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(DriverTheme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: DriverTheme.accent.opacity(0.18), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background((isSelected ? DriverTheme.subtleGreen : DriverTheme.subtleFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(isSelected ? DriverTheme.accent : DriverTheme.primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? DriverTheme.accent.opacity(0.18) : DriverTheme.cardStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
