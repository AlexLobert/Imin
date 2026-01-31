import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var showSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else {
                if sessionManager.session == nil {
                    if hasSeenOnboarding {
                        LoginView()
                    } else {
                        OnboardingView {
                            hasSeenOnboarding = true
                        }
                    }
                } else {
                    MainTabView()
                }
            }
        }
        .onAppear {
            sessionManager.restoreSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
        .task {
            print("API_BASE_URL =", ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "nil")
        }
    }
}
