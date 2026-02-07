import Foundation

struct ProfileService {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func fetchProfile(session: UserSession) async throws -> ProfileInfo {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "name,handle"),
            URLQueryItem(name: "id", value: "eq.\(session.userId)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else {
            throw ProfileServiceError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        addHeaders(to: &request, session: session)

        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([ProfileRow].self, from: data)
        guard let row = rows.first else {
            return ProfileInfo(name: nil, handle: nil)
        }
        return ProfileInfo(name: row.name, handle: row.handle)
    }

    func updateProfile(name: String?, handle: String?, session: UserSession) async throws -> ProfileInfo {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "on_conflict", value: "id")
        ]

        guard let url = components?.url else {
            throw ProfileServiceError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        let payload = ProfileUpdatePayload(id: session.userId, name: name, handle: handle)
        request.httpBody = try JSONEncoder().encode([payload])

        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([ProfileRow].self, from: data)
        guard let row = rows.first else {
            return ProfileInfo(name: name, handle: handle)
        }
        return ProfileInfo(name: row.name, handle: row.handle)
    }

    private func addHeaders(to request: inout URLRequest, session: UserSession) {
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ProfileServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

private struct ProfileRow: Decodable {
    let name: String?
    let handle: String?
}

private struct ProfileUpdatePayload: Encodable {
    let id: String
    let name: String?
    let handle: String?
}

struct ProfileInfo: Equatable {
    let name: String?
    let handle: String?
}

enum ProfileServiceError: Error, LocalizedError {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid profile URL"
        case .invalidResponse:
            return "Invalid response from profile service"
        case let .requestFailed(statusCode):
            return "Profile update failed (\(statusCode))"
        }
    }
}
