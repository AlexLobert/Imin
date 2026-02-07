import SwiftUI

@main
struct IminApp: App {
    @StateObject private var sessionManager: SessionManager
    @StateObject private var chatStore: ChatStore
    @StateObject private var circleStore = CircleStore()
    @StateObject private var safetyStore = SafetyStore()
    @StateObject private var statusStore = StatusStore()
    @StateObject private var privacyStore = PrivacyStore()

    init() {
        let authClient: AuthClient = {
            switch AppEnvironment.backend {
            case .supabase:
                return SupabaseAuthClient()
            case .kris:
                return KrisAuthClient()
            }
        }()

        _sessionManager = StateObject(
            wrappedValue: SessionManager(
                authClient: authClient,
                keychain: KeychainStore()
            )
        )
        _chatStore = StateObject(wrappedValue: ChatStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .environmentObject(chatStore)
                .environmentObject(circleStore)
                .environmentObject(safetyStore)
                .environmentObject(statusStore)
                .environmentObject(privacyStore)
        }
    }
}
