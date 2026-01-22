import SwiftUI
import UIKit

struct MainTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear

        let unselectedColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 1.0)
        let selectedColor = UIColor(red: 0.98, green: 0.85, blue: 0.2, alpha: 1.0)

        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Status")
                }

            CirclesView()
                .tabItem {
                    Image(systemName: "circle.grid.2x2.fill")
                    Text("Circles")
                }

            ChatsView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
        }
        .tint(Color(red: 0.98, green: 0.85, blue: 0.2))
    }
}
