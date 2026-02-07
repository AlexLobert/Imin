import SwiftUI

struct GlassTabBar: View {
    @Binding var selection: MainTabView.Tab
    let unreadTotal: Int

    private let accent = AppStyle.mint
    private let inactive = Color(red: 0.60, green: 0.62, blue: 0.66)

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.status, systemName: "bolt.fill", title: "Connect", showsBadge: unreadTotal > 0)
            tabButton(.circles, systemName: "circle.grid.2x2.fill", title: "Circles")
            tabButton(.profile, systemName: "person.fill", title: "Profile")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(glassBackground)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private var glassBackground: some View {
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
                .clipShape(Capsule(style: .continuous))
                .blendMode(.screen)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private func tabButton(_ tab: MainTabView.Tab, systemName: String, title: String, showsBadge: Bool = false) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                selection = tab
            }
        } label: {
            let isSelected = selection == tab
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(accent.opacity(0.22), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
                        }

                        Image(systemName: systemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? accent : inactive)
                    }
                    .frame(width: 44, height: 34)

                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? DesignColors.textPrimary : inactive)
                }
                .frame(maxWidth: .infinity)

                if showsBadge {
                    Text("\(min(unreadTotal, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent))
                        .offset(x: 2, y: -4)
                        .accessibilityLabel(Text("Unread \(unreadTotal)"))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

