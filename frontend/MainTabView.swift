import SwiftUI

struct MainTabView: View {
    enum Tab {
        case status
        case circles
        case profile
    }

    @State private var selection: Tab = .status
    @EnvironmentObject private var chatStore: ChatStore

    var body: some View {
        TabView(selection: $selection) {
            ConnectView()
                .tag(Tab.status)

            CirclesView()
                .tag(Tab.circles)

            ProfileView()
                .tag(Tab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selection: $selection, unreadTotal: chatStore.unreadTotal)
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selection: MainTabView.Tab
    let unreadTotal: Int

    private let background = Color(red: 0.99, green: 0.99, blue: 0.98)
    private let selected = Color(red: 0.14, green: 0.62, blue: 0.36)
    private let unselected = Color(red: 0.67, green: 0.69, blue: 0.72)

    var body: some View {
        HStack {
            tabButton(.status, systemName: "bolt.fill", showsBadge: unreadTotal > 0)
            Spacer()
            tabButton(.circles, systemName: "circle.grid.2x2.fill")
            Spacer()
            tabButton(.profile, systemName: "person.fill")
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 8)
        .background(background)
        .overlay(
            Divider()
                .background(Color.black.opacity(0.08)),
            alignment: .top
        )
    }

    private func tabButton(_ tab: MainTabView.Tab, systemName: String, showsBadge: Bool = false) -> some View {
        Button {
            selection = tab
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(selection == tab ? selected : unselected)
                    .frame(width: 32, height: 32)

                if showsBadge {
                    Text("\(min(unreadTotal, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Circle().fill(selected))
                        .offset(x: 6, y: -6)
                        .accessibilityLabel(Text("Unread \(unreadTotal)"))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label(for: tab)))
    }

    private func label(for tab: MainTabView.Tab) -> String {
        switch tab {
        case .status:
            return "Status"
        case .circles:
            return "Circles"
        case .profile:
            return "Profile"
        }
    }
}
