import Foundation

struct FriendRequestItem: Identifiable, Equatable {
    let id: String
    let senderId: String
    let name: String
    let handle: String
}

struct FriendListItem: Identifiable, Equatable {
    let id: String
    let name: String
    let handle: String
}

enum FriendRequestStatus: String {
    case pending
    case accepted
    case declined
}

struct FriendRequestService {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func sendRequest(to input: String, session: UserSession) async throws {
        let receiverId = try await resolveRecipientId(from: input, session: session)
        if receiverId == session.userId {
            throw FriendRequestError.invalidRecipient
        }

        let url = config.url.appendingPathComponent("/rest/v1/friend_requests")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = FriendRequestPayload(
            senderId: session.userId,
            receiverId: receiverId,
            status: FriendRequestStatus.pending.rawValue
        )
        request.httpBody = try JSONEncoder().encode(payload)

        _ = try await data(for: request)
    }

    func fetchPendingRequests(session: UserSession) async throws -> [FriendRequestItem] {
        let url = try makePendingRequestsUrl(receiverId: session.userId)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)

        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([FriendRequestRow].self, from: data)
        let senderIds = rows.map { $0.senderId }
        let profiles = try await fetchProfiles(ids: senderIds, session: session)
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return rows.map { row in
            let profile = profileMap[row.senderId]
            let name = profile?.name ?? profile?.handle ?? shortId(row.senderId)
            let handle = profile?.handle ?? "@imin"
            return FriendRequestItem(
                id: row.id,
                senderId: row.senderId,
                name: name,
                handle: handle
            )
        }
    }

    func updateRequestStatus(id: String, status: FriendRequestStatus, session: UserSession) async throws {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/friend_requests"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)")
        ]

        guard let url = components?.url else {
            throw FriendRequestError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(FriendRequestStatusPayload(status: status.rawValue))

        _ = try await data(for: request)
    }

    func fetchFriends(session: UserSession) async throws -> [FriendListItem] {
        let url = try makeFriendsUrl(userId: session.userId)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)

        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([FriendRequestRow].self, from: data)

        let friendIds = rows.compactMap { row -> String? in
            if row.senderId == session.userId {
                return row.receiverId
            }
            if row.receiverId == session.userId {
                return row.senderId
            }
            return nil
        }

        let profiles = try await fetchProfiles(ids: friendIds, session: session)
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return friendIds.compactMap { id in
            let profile = profileMap[id]
            let name = profile?.name ?? profile?.handle ?? shortId(id)
            let handle = profile?.handle ?? "@imin"
            return FriendListItem(id: id, name: name, handle: handle)
        }
    }

    private func resolveRecipientId(from input: String, session: UserSession) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FriendRequestError.invalidRecipient
        }

        let url = config.url.appendingPathComponent("/rest/v1/rpc/resolve_profile_id")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["query": trimmed])

        let data = try await data(for: request)
        if let raw = String(data: data, encoding: .utf8),
           raw.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            throw FriendRequestError.notFound
        }

        if let id = try? JSONDecoder().decode(String.self, from: data) {
            return id
        }
        if let ids = try? JSONDecoder().decode([String].self, from: data),
           let id = ids.first {
            return id
        }

        throw FriendRequestError.notFound
    }

    private func fetchProfiles(ids: [String], session: UserSession) async throws -> [ProfileLookupRow] {
        guard !ids.isEmpty else { return [] }
        let joined = ids.joined(separator: ",")

        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,handle,name"),
            URLQueryItem(name: "id", value: "in.(\(joined))")
        ]

        guard let url = components?.url else {
            throw FriendRequestError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)

        let data = try await data(for: request)
        return try JSONDecoder().decode([ProfileLookupRow].self, from: data)
    }

    private func makePendingRequestsUrl(receiverId: String) throws -> URL {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/friend_requests"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,sender_id,receiver_id,status,created_at"),
            URLQueryItem(name: "receiver_id", value: "eq.\(receiverId)"),
            URLQueryItem(name: "status", value: "eq.\(FriendRequestStatus.pending.rawValue)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components?.url else {
            throw FriendRequestError.invalidUrl
        }

        return url
    }

    private func makeFriendsUrl(userId: String) throws -> URL {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/friend_requests"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,sender_id,receiver_id,status"),
            URLQueryItem(name: "or", value: "(sender_id.eq.\(userId),receiver_id.eq.\(userId))"),
            URLQueryItem(name: "status", value: "eq.\(FriendRequestStatus.accepted.rawValue)")
        ]

        guard let url = components?.url else {
            throw FriendRequestError.invalidUrl
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
            throw FriendRequestError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            throw FriendRequestError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func shortId(_ id: String) -> String {
        String(id.prefix(6))
    }
}

private struct FriendRequestRow: Decodable {
    let id: String
    let senderId: String
    let receiverId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case status
    }
}

private struct FriendRequestPayload: Encodable {
    let senderId: String
    let receiverId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case status
    }
}

private struct FriendRequestStatusPayload: Encodable {
    let status: String
}

private struct ProfileLookupRow: Decodable {
    let id: String
    let name: String?
    let handle: String?
    let email: String?
}

enum FriendRequestError: Error, LocalizedError {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case invalidRecipient
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid friend request URL"
        case .invalidResponse:
            return "Invalid response from friend request service"
        case let .requestFailed(statusCode, message):
            return "Friend request failed (\(statusCode)): \(message)"
        case .invalidRecipient:
            return "Please enter a valid handle or email."
        case .notFound:
            return "We couldn't find that user."
        }
    }
}

private func decodeErrorMessage(from data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let message = json["message"] as? String {
            return message
        }
        if let error = json["error"] as? String {
            return error
        }
        if let errorDesc = json["error_description"] as? String {
            return errorDesc
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
