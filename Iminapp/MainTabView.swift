import SwiftUI
import UIKit

struct MainTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1.0)
        appearance.shadowColor = UIColor(white: 0.9, alpha: 1.0)

        let unselectedColor = UIColor(red: 0.67, green: 0.69, blue: 0.72, alpha: 1.0)
        let selectedColor = UIColor(red: 0.14, green: 0.62, blue: 0.36, alpha: 1.0)

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
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
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
        .tint(Color(red: 0.14, green: 0.62, blue: 0.36))
    }
}
