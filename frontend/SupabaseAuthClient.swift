import Foundation

protocol AuthClient {
    func sendOtp(email: String) async throws
    func verifyOtp(email: String, token: String) async throws -> UserSession
    func refreshSession(refreshToken: String) async throws -> UserSession
    func signOut(session: UserSession) async throws
}

struct SupabaseConfig {
    let url: URL
    let anonKey: String

    static let `default` = SupabaseConfig(
        url: URL(string: "https://mcgviepzewadfnsmknqr.supabase.co")!,
        anonKey: "sb_publishable_O_d8pmWaw4Ju_Ax42t9VXw_AIDiBT-K"
    )
}

struct SupabaseAuthClient: AuthClient {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func sendOtp(email: String) async throws {
        let body = SupabaseOtpRequest(email: email, createUser: true)
        let request = try makeRequest(path: "/auth/v1/otp", body: body)
        _ = try await data(for: request)
    }

    func verifyOtp(email: String, token: String) async throws -> UserSession {
        let body = SupabaseVerifyRequest(email: email, token: token, type: "email")
        let request = try makeRequest(path: "/auth/v1/verify", body: body)
        let data = try await data(for: request)
        let response = try JSONDecoder().decode(SupabaseVerifyResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))

        return UserSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userId: response.user.id,
            expiresAt: expiresAt
        )
    }

    func signOut(session: UserSession) async throws {
        var request = URLRequest(url: config.url.appendingPathComponent("/auth/v1/logout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        _ = try await data(for: request)
    }

    func refreshSession(refreshToken: String) async throws -> UserSession {
        var components = URLComponents(url: config.url.appendingPathComponent("/auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]

        guard let url = components?.url else {
            throw SupabaseAuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseRefreshRequest(refreshToken: refreshToken))

        let data = try await data(for: request)
        let response = try JSONDecoder().decode(SupabaseVerifyResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))

        return UserSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userId: response.user.id,
            expiresAt: expiresAt
        )
    }

    private func makeRequest<T: Encodable>(path: String, body: T) throws -> URLRequest {
        var request = URLRequest(url: config.url.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SupabaseAuthError.requestFailed(message: decodeErrorMessage(from: data))
        }

        return data
    }

    private func decodeErrorMessage(from data: Data) -> String {
        if let error = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
            return error.errorDescription ?? error.message ?? "Unknown error"
        }

        return "Unknown error"
    }
}

private struct SupabaseOtpRequest: Encodable {
    let email: String
    let createUser: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case createUser = "create_user"
    }
}

private struct SupabaseVerifyRequest: Encodable {
    let email: String
    let token: String
    let type: String
}

private struct SupabaseRefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct SupabaseVerifyResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

private struct SupabaseUser: Decodable {
    let id: String
}

private struct SupabaseErrorResponse: Decodable {
    let message: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case message = "msg"
        case errorDescription = "error_description"
    }
}

enum SupabaseAuthError: Error {
    case invalidResponse
    case requestFailed(message: String)
}
