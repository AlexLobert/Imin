import Foundation

// Lightweight safety + moderation endpoints for App Store review (Block + Report).
//
// Backed by Supabase tables:
// - public.user_blocks (blocker_id, blocked_id)
// - public.content_reports (reporter_id, thread_id, message_id, reported_user_id, reason, details)
//
// See the SQL in the assistant response for schema + RLS policies.

protocol SafetyServiceProtocol {
    func fetchBlockedUserIds(session: UserSession) async throws -> Set<UserID>
    func blockUser(blockedUserId: UserID, session: UserSession) async throws
    func unblockUser(blockedUserId: UserID, session: UserSession) async throws
    func createReport(
        threadId: String,
        messageId: String?,
        reportedUserId: UserID?,
        reason: String,
        details: String?,
        session: UserSession
    ) async throws
}

struct SupabaseSafetyService: SafetyServiceProtocol {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func fetchBlockedUserIds(session: UserSession) async throws -> Set<UserID> {
        let url = try makeUrl(
            path: "/rest/v1/user_blocks",
            queryItems: [
                URLQueryItem(name: "select", value: "blocked_id"),
                URLQueryItem(name: "blocker_id", value: "eq.\(session.userId)")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)

        let data = try await data(for: request)
        let rows = try makeDecoder().decode([UserBlockRow].self, from: data)
        return Set(rows.map(\.blockedId))
    }

    func blockUser(blockedUserId: UserID, session: UserSession) async throws {
        let url = try makeUrl(path: "/rest/v1/user_blocks", queryItems: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try makeEncoder().encode([UserBlockInsertRow(blockerId: session.userId, blockedId: blockedUserId)])
        _ = try await data(for: request)
    }

    func unblockUser(blockedUserId: UserID, session: UserSession) async throws {
        let url = try makeUrl(
            path: "/rest/v1/user_blocks",
            queryItems: [
                URLQueryItem(name: "blocker_id", value: "eq.\(session.userId)"),
                URLQueryItem(name: "blocked_id", value: "eq.\(blockedUserId)")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request, session: session)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await data(for: request)
    }

    func createReport(
        threadId: String,
        messageId: String?,
        reportedUserId: UserID?,
        reason: String,
        details: String?,
        session: UserSession
    ) async throws {
        let url = try makeUrl(path: "/rest/v1/content_reports", queryItems: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload = ContentReportInsertRow(
            reporterId: session.userId,
            threadId: threadId,
            messageId: messageId,
            reportedUserId: reportedUserId,
            reason: reason,
            details: details
        )
        request.httpBody = try makeEncoder().encode([payload])
        _ = try await data(for: request)
    }

    private func makeUrl(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: config.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw SafetyServiceError.invalidUrl
        }
        return url
    }

    private func addHeaders(to request: inout URLRequest, session: UserSession) {
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SafetyServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            throw SafetyServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(DateCoders.decodeISO8601)
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
            if let details = json["details"] as? String {
                return details
            }
            if let hint = json["hint"] as? String {
                return hint
            }
        }
        return "Request failed"
    }
}

private struct UserBlockRow: Decodable {
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
    }
}

private struct UserBlockInsertRow: Encodable {
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

private struct ContentReportInsertRow: Encodable {
    let reporterId: String
    let threadId: String
    let messageId: String?
    let reportedUserId: String?
    let reason: String
    let details: String?

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case threadId = "thread_id"
        case messageId = "message_id"
        case reportedUserId = "reported_user_id"
        case reason
        case details
    }
}

enum SafetyServiceError: Error, LocalizedError {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid safety URL"
        case .invalidResponse:
            return "Invalid response from safety service"
        case let .requestFailed(statusCode, message):
            return "Safety error (\(statusCode)): \(message)"
        }
    }
}

