import Foundation

struct AvailabilityService {
    private let config: SupabaseConfig
    private let urlSession: URLSession
    private let apiBaseURL: URL?

    init(
        config: SupabaseConfig = .default,
        urlSession: URLSession = .shared,
        apiBaseURL: URL? = Environment.isUsingAPIBaseURL ? Environment.baseURL : nil
    ) {
        self.config = config
        self.urlSession = urlSession
        self.apiBaseURL = apiBaseURL
    }

    func fetchAvailability(session: UserSession) async throws -> Availability? {
        if let apiBaseURL = apiBaseURL {
            return try await fetchAvailabilityFromBackend(baseURL: apiBaseURL, session: session)
        }
        return try await fetchAvailabilityFromSupabase(session: session)
    }

    func upsertAvailability(state: AvailabilityState, expiresAt: Date?, session: UserSession) async throws -> Availability {
        if let apiBaseURL = apiBaseURL {
            return try await upsertAvailabilityToBackend(
                baseURL: apiBaseURL,
                state: state,
                expiresAt: expiresAt,
                session: session
            )
        }
        return try await upsertAvailabilityToSupabase(
            state: state,
            expiresAt: expiresAt,
            session: session
        )
    }

    private func fetchAvailabilityFromBackend(baseURL: URL, session: UserSession) async throws -> Availability? {
        let url = baseURL.appendingPathComponent("status")

#if DEBUG
        print("AvailabilityService GET \(url.absoluteString)")
#endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await data(for: request)
        let response = try JSONDecoder().decode(BackendStatusResponse.self, from: data)
        guard let state = AvailabilityState(backendStatus: response.status) else {
            throw AvailabilityServiceError.invalidBackendStatus
        }

        return Availability(userId: session.userId, state: state, expiresAt: nil)
    }

    private func upsertAvailabilityToBackend(
        baseURL: URL,
        state: AvailabilityState,
        expiresAt: Date?,
        session: UserSession
    ) async throws -> Availability {
        let url = baseURL.appendingPathComponent("set_status")

#if DEBUG
        print("AvailabilityService POST \(url.absoluteString)")
#endif

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = BackendStatusRequest(status: state.backendStatus)
        request.httpBody = try JSONEncoder().encode(payload)

        let data = try await data(for: request)
        let response = try JSONDecoder().decode(BackendStatusResponse.self, from: data)
        guard let updatedState = AvailabilityState(backendStatus: response.status) else {
            throw AvailabilityServiceError.invalidBackendStatus
        }

        return Availability(userId: session.userId, state: updatedState, expiresAt: expiresAt)
    }

    private func fetchAvailabilityFromSupabase(session: UserSession) async throws -> Availability? {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/availability"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "user_id,state,expires_at"),
            URLQueryItem(name: "user_id", value: "eq.\(session.userId)"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else {
            throw AvailabilityServiceError.invalidUrl
        }

#if DEBUG
        print("AvailabilityService GET \(url.absoluteString)")
#endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        addHeaders(to: &request, session: session)

        let data = try await data(for: request)
        let entries = try makeDecoder().decode([Availability].self, from: data)
        return entries.first
    }

    private func upsertAvailabilityToSupabase(
        state: AvailabilityState,
        expiresAt: Date?,
        session: UserSession
    ) async throws -> Availability {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/availability"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "on_conflict", value: "user_id")
        ]

        guard let url = components?.url else {
            throw AvailabilityServiceError.invalidUrl
        }

#if DEBUG
        print("AvailabilityService POST \(url.absoluteString)")
#endif

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let payload = AvailabilityPayload(userId: session.userId, state: state, expiresAt: expiresAt)
        request.httpBody = try makeEncoder().encode([payload])

        let data = try await data(for: request)
        let entries = try makeDecoder().decode([Availability].self, from: data)
        guard let entry = entries.first else {
            throw AvailabilityServiceError.emptyResponse
        }

        return entry
    }

    private func addHeaders(to request: inout URLRequest, session: UserSession) {
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func data(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AvailabilityServiceError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = decodeErrorMessage(from: data)
                throw AvailabilityServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
            }

            return data
        } catch {
            throw AvailabilityServiceError.network(message: error.localizedDescription)
        }
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func decodeErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String {
                return message
            }
            if let error = json["error"] as? String {
                return error
            }
            if let errorDict = json["error"] as? [String: Any],
               let message = errorDict["message"] as? String {
                return message
            }
        }
        return "Request failed"
    }
}

private struct AvailabilityPayload: Encodable {
    let userId: String
    let state: AvailabilityState
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case state
        case expiresAt = "expires_at"
    }
}

enum AvailabilityServiceError: Error, LocalizedError {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case emptyResponse
    case network(message: String)
    case invalidBackendStatus

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid availability URL"
        case .invalidResponse:
            return "Invalid response from availability service"
        case let .requestFailed(statusCode, message):
            return "Availability error (\(statusCode)): \(message)"
        case .emptyResponse:
            return "No availability data returned"
        case let .network(message):
            return "Network error: \(message)"
        case .invalidBackendStatus:
            return "Invalid availability status from backend"
        }
    }
}

private struct BackendStatusRequest: Encodable {
    let status: String
}

private struct BackendStatusResponse: Decodable {
    let status: String
}

private extension AvailabilityState {
    init?(backendStatus: String) {
        switch backendStatus.lowercased() {
        case "in":
            self = .inOffice
        case "out":
            self = .out
        default:
            return nil
        }
    }

    var backendStatus: String {
        switch self {
        case .inOffice:
            return "In"
        case .out:
            return "Out"
        }
    }
}
