import SwiftUI

enum AppStyle {
    static let screenBG = DesignColors.background
    static let cardBG = Color(.systemBackground)

    static let cardCorner: CGFloat = 28
    static let cardShadowOpacity: Double = 0.05
    static let cardShadowRadius: CGFloat = 20
    static let cardShadowY: CGFloat = 4

    static let mint = Color(red: 0.5, green: 0.85, blue: 0.75)

    static let pillCorner: CGFloat = 999
    static let pillHeight: CGFloat = 38
}

struct AppCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppStyle.cardCorner, style: .continuous)
                    .fill(AppStyle.cardBG)
                    .shadow(
                        color: .black.opacity(AppStyle.cardShadowOpacity),
                        radius: AppStyle.cardShadowRadius,
                        x: 0,
                        y: AppStyle.cardShadowY
                    )
            )
    }
}

extension View {
    func appCard() -> some View { self.modifier(AppCard()) }
}

enum AppPillKind {
    case mint
    case neutral
    case destructive
}

struct AppPillButtonStyle: ButtonStyle {
    let kind: AppPillKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: AppStyle.pillHeight)
            .padding(.horizontal, 16)
            .background(backgroundView(configuration: configuration))
            .foregroundStyle(foreground)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundView(configuration: Configuration) -> some View {
        let base: Color = {
            switch kind {
            case .mint: return AppStyle.mint.opacity(0.20)
            case .neutral: return Color(.systemGray5)
            case .destructive: return Color.red.opacity(0.12)
            }
        }()

        return RoundedRectangle(cornerRadius: AppStyle.pillCorner, style: .continuous)
            .fill(base.opacity(configuration.isPressed ? 0.85 : 1.0))
    }

    private var foreground: Color {
        switch kind {
        case .destructive: return .red
        default: return .primary
        }
    }
}

struct FloatingIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: .black.opacity(AppStyle.cardShadowOpacity),
                            radius: 10,
                            x: 0,
                            y: 6
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
