import SwiftUI

struct GlassCardStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            .blendMode(.overlay)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.60),
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .blendMode(.screen)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            )
    }
}

extension View {
    func glassCardStyle(cornerRadius: CGFloat = AppStyle.cardCorner) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }
}

