import SwiftUI

enum ConnectColors {
    static let background = DesignColors.background
    static let cardBackground = DesignColors.card
    static let accentGreen = DesignColors.accentGreen
    static let accentGreenSoft = DesignColors.accentGreen.opacity(0.28)
    static let textPrimary = DesignColors.textPrimary
    static let textSecondary = DesignColors.textSecondary
    static let shadow = Color.black.opacity(0.06)
    static let chipBackground = Color.white
    static let chipBorder = Color.black.opacity(0.08)
    static let divider = Color.black.opacity(0.05)
    static let muted = Color(red: 0.94, green: 0.94, blue: 0.94)
}

struct SoftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ConnectColors.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(ConnectColors.chipBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 4)
    }
}

extension View {
    func softCard() -> some View {
        modifier(SoftCardModifier())
    }
}

struct FilterPillStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppStyle.mint.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? AppStyle.mint : ConnectColors.textSecondary)
    }
}
