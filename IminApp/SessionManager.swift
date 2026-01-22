import Foundation

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authClient: AuthClient
    private let keychain: KeychainStore
    private let keychainService = "IminSession"
    private let keychainAccount = "supabase"

    init(authClient: AuthClient, keychain: KeychainStore) {
        self.authClient = authClient
        self.keychain = keychain
    }

    func restoreSession() {
        do {
            if let data = try keychain.read(service: keychainService, account: keychainAccount) {
                let decoded = try JSONDecoder().decode(UserSession.self, from: data)
                session = decoded
                Task {
                    await refreshSessionIfNeeded()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendOtp(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await authClient.sendOtp(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func verifyOtp(email: String, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let newSession = try await authClient.verifyOtp(email: email, token: token)
            session = newSession
            try persistSession(newSession)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshSessionIfNeeded() async {
        guard let currentSession = session else { return }
        let refreshThreshold = Date().addingTimeInterval(60)
        guard currentSession.expiresAt <= refreshThreshold else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let refreshed = try await authClient.refreshSession(refreshToken: currentSession.refreshToken)
            session = refreshed
            try persistSession(refreshed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func validSession() async -> UserSession? {
        await refreshSessionIfNeeded()
        return session
    }

    func signOut() async {
        guard let currentSession = session else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authClient.signOut(session: currentSession)
        } catch {
            errorMessage = error.localizedDescription
        }

        session = nil
        try? keychain.delete(service: keychainService, account: keychainAccount)
    }

    private func persistSession(_ session: UserSession) throws {
        let data = try JSONEncoder().encode(session)
        try keychain.save(data: data, service: keychainService, account: keychainAccount)
    }
}
