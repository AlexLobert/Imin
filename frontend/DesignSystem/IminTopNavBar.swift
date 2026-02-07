import SwiftUI
import UIKit

struct IminTopNavBar<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        ZStack {
            HStack {
                IminLogoBubble()
                Spacer()
                trailing()
            }

            ZStack {
                Image("IminLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .opacity(0.03)
                    .offset(y: -10)

                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                    .blendMode(.overlay)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                    )
            }
        }
        .padding(.vertical, 6)
    }
}

struct IminLogoBubble: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

            Image("ImInLogov2")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
        .frame(width: 36, height: 36)
    }
}

struct TopIconCircleButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                        .overlay(
                            Circle()
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
                            .clipShape(Circle())
                            .blendMode(.screen)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppStyle.mint.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
