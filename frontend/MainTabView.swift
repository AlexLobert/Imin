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
            GlassTabBar(selection: $selection, unreadTotal: chatStore.unreadTotal)
        }
    }
}
