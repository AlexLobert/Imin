import Foundation

@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authClient: AuthClient
    private let keychain: KeychainStore
    private let keychainService = "IminSession"
    private let keychainAccount: String

    init(authClient: AuthClient, keychain: KeychainStore) {
        self.authClient = authClient
        self.keychain = keychain
        switch AppEnvironment.backend {
        case .supabase:
            keychainAccount = "supabase"
        case .kris:
            keychainAccount = "kris-backend"
        }
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

    func sendOtp(email: String, createUser: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            try await authClient.sendOtp(email: email, createUser: createUser)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func verifyOtp(email: String, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            var newSession = try await authClient.verifyOtp(email: email, token: token)
            if newSession.email == nil {
                newSession = newSession.withEmail(email)
            }
            session = newSession
            try persistSession(newSession)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let newSession = try await authClient.login(email: email, password: password)
            session = newSession
            try persistSession(newSession)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshSessionIfNeeded() async {
        guard authClient.supportsRefresh else { return }
        guard let currentSession = session else { return }
        let refreshThreshold = Date().addingTimeInterval(60)
        guard currentSession.expiresAt <= refreshThreshold else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let refreshed = try await authClient.refreshSession(refreshToken: currentSession.refreshToken)
            let updated = refreshed.email == nil ? refreshed.withEmail(currentSession.email) : refreshed
            session = updated
            try persistSession(updated)
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

    func updateEmail(to newEmail: String) async {
        guard let currentSession = session else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authClient.updateEmail(newEmail: newEmail, session: currentSession)
            let updated = currentSession.withEmail(newEmail)
            session = updated
            try persistSession(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        guard let currentSession = session else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authClient.deleteAccount(session: currentSession)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        session = nil
        try? keychain.delete(service: keychainService, account: keychainAccount)
    }

    private func persistSession(_ session: UserSession) throws {
        let data = try JSONEncoder().encode(session)
        try keychain.save(data: data, service: keychainService, account: keychainAccount)
    }
}
