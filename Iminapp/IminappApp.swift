import SwiftUI

@main
struct IminApp: App {
    @State private var showLaunchOverlay = true
    @State private var launchStartDate = Date()
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
                .overlay {
                    if showLaunchOverlay {
                        LaunchOverlayView(isPresented: $showLaunchOverlay) {
                            dismissLaunchOverlay(animated: true)
                        }
                        .transition(.opacity)
                    }
                }
                .onChange(of: sessionManager.session) { _ in
                    dismissLaunchOverlay(animated: true)
                }

        }
    }

    private func dismissLaunchOverlay(animated: Bool) {
        guard showLaunchOverlay else { return }
        let elapsed = Date().timeIntervalSince(launchStartDate)
        let minimumDisplay: TimeInterval = 0.6
        let delay = max(0, minimumDisplay - elapsed)
        let action = {
            if animated {
                withAnimation(.easeOut(duration: 0.35)) {
                    showLaunchOverlay = false
                }
            } else {
                showLaunchOverlay = false
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        } else {
            action()
        }
    }
}
