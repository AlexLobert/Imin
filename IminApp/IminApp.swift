import SwiftUI

@main
struct IminApp: App {
    @StateObject private var sessionManager = SessionManager(
        authClient: SupabaseAuthClient(),
        keychain: KeychainStore()
    )
    @StateObject private var chatStore = ChatStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .environmentObject(chatStore)
        }
    }
}
