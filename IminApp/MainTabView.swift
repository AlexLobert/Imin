import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Status")
                }

            ChatsView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
        }
        .tint(Color(red: 0.55, green: 0.6, blue: 0.7))
    }
}
