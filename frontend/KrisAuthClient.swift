import Foundation

struct KrisAuthClient: AuthClient {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    let authMode: AuthMode = .password
    let supportsRefresh = false

    func sendOtp(email: String, createUser: Bool) async throws {
        throw AuthClientError.unsupported
    }

    func verifyOtp(email: String, token: String) async throws -> UserSession {
        throw AuthClientError.unsupported
    }

    func login(email: String, password: String) async throws -> UserSession {
        try await apiClient.login(email: email, password: password)
        return UserSession.kris(email: email)
    }

    func refreshSession(refreshToken: String) async throws -> UserSession {
        throw AuthClientError.unsupported
    }

    func signOut(session: UserSession) async throws {
        try await apiClient.logout()
    }

    func updateEmail(newEmail: String, session: UserSession) async throws {
        throw AuthClientError.unsupported
    }

    func deleteAccount(session: UserSession) async throws {
        throw AuthClientError.unsupported
    }
}
