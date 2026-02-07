import Foundation

protocol FriendsAPI {
    func searchUsers(query: String, session: UserSession) async throws -> [UserSearchResult]
    func sendFriendRequest(to userId: String, session: UserSession) async throws
    func listFriends(session: UserSession) async throws -> [PublicUser]
    func matchContacts(hashes: [String], session: UserSession) async throws -> [UserSearchResult]
    func uploadContactHashes(hashes: [String], session: UserSession) async throws
}

final class FriendsAPIClient: FriendsAPI {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func searchUsers(query: String, session: UserSession) async throws -> [UserSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

        let profiles = try await searchProfiles(handleQuery: handle, session: session)
        let pending = try await fetchOutgoingPending(session: session)
        let friends = try await fetchFriendIds(session: session)

        return profiles
            .filter { $0.id != session.userId }
            .map { profile in
                let state: FriendshipState
                if friends.contains(profile.id) {
                    state = .friends
                } else if pending.contains(profile.id) {
                    state = .outgoingPending
                } else {
                    state = .none
                }

                return UserSearchResult(
                    id: profile.id,
                    name: profile.name ?? profile.handle ?? "User",
                    handle: profile.handle ?? ""
                , state: state)
            }
    }

    func sendFriendRequest(to userId: String, session: UserSession) async throws {
        let url = config.url.appendingPathComponent("/rest/v1/friend_requests")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = FriendRequestPayload(
            senderId: session.userId,
            receiverId: userId,
            status: "pending"
        )
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await data(for: request)
    }

    func listFriends(session: UserSession) async throws -> [PublicUser] {
        let friendIds = try await fetchFriendIds(session: session)
        guard !friendIds.isEmpty else { return [] }
        let profiles = try await fetchProfiles(ids: friendIds, session: session)
        return profiles.map { profile in
            PublicUser(
                id: profile.id,
                name: profile.name ?? profile.handle ?? "User",
                handle: profile.handle ?? ""
            )
        }
    }

    func matchContacts(hashes: [String], session: UserSession) async throws -> [UserSearchResult] {
        guard !hashes.isEmpty else { return [] }

        let profiles = try await matchContactProfiles(hashes: hashes, session: session)
        let pending = try await fetchOutgoingPending(session: session)
        let friends = try await fetchFriendIds(session: session)

        return profiles
            .filter { $0.id != session.userId }
            .map { profile in
                let state: FriendshipState
                if friends.contains(profile.id) {
                    state = .friends
                } else if pending.contains(profile.id) {
                    state = .outgoingPending
                } else {
                    state = .none
                }

                return UserSearchResult(
                    id: profile.id,
                    name: profile.name ?? profile.handle ?? "User",
                    handle: profile.handle ?? "",
                    state: state
                )
            }
    }

    func uploadContactHashes(hashes: [String], session: UserSession) async throws {
        guard !hashes.isEmpty else { return }
        let url = config.url.appendingPathComponent("/rest/v1/contact_hashes")

        let payload = hashes.map { ContactHashPayload(userId: session.userId, hash: $0) }
        let chunks = payload.chunked(into: 500)

        for chunk in chunks {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            addHeaders(to: &request, session: session)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONEncoder().encode(chunk)
            _ = try await data(for: request)
        }
    }

    private func searchProfiles(handleQuery: String, session: UserSession) async throws -> [ProfileLookupRow] {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,handle,name"),
            URLQueryItem(name: "handle", value: "ilike.*\(handleQuery)*"),
            URLQueryItem(name: "searchable_by_handle", value: "eq.true"),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components?.url else { throw FriendsAPIError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let data = try await data(for: request)
        return try JSONDecoder().decode([ProfileLookupRow].self, from: data)
    }

    private func fetchOutgoingPending(session: UserSession) async throws -> Set<String> {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/friend_requests"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "receiver_id"),
            URLQueryItem(name: "sender_id", value: "eq.\(session.userId)"),
            URLQueryItem(name: "status", value: "eq.pending")
        ]
        guard let url = components?.url else { throw FriendsAPIError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([PendingRow].self, from: data)
        return Set(rows.map { $0.receiverId })
    }

    private func fetchFriendIds(session: UserSession) async throws -> Set<String> {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/friend_requests"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "sender_id,receiver_id,status"),
            URLQueryItem(name: "or", value: "(sender_id.eq.\(session.userId),receiver_id.eq.\(session.userId))"),
            URLQueryItem(name: "status", value: "eq.accepted")
        ]
        guard let url = components?.url else { throw FriendsAPIError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let data = try await data(for: request)
        let rows = try JSONDecoder().decode([FriendRequestRowLite].self, from: data)
        let ids = rows.compactMap { row -> String? in
            if row.senderId == session.userId {
                return row.receiverId
            }
            if row.receiverId == session.userId {
                return row.senderId
            }
            return nil
        }
        return Set(ids)
    }

    private func fetchProfiles(ids: Set<String>, session: UserSession) async throws -> [ProfileLookupRow] {
        let joined = ids.joined(separator: ",")
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,handle,name"),
            URLQueryItem(name: "id", value: "in.(\(joined))")
        ]
        guard let url = components?.url else { throw FriendsAPIError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let data = try await data(for: request)
        return try JSONDecoder().decode([ProfileLookupRow].self, from: data)
    }

    private func matchContactProfiles(hashes: [String], session: UserSession) async throws -> [ProfileLookupRow] {
        let url = config.url.appendingPathComponent("/rest/v1/rpc/match_contacts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = MatchContactsPayload(hashes: hashes)
        request.httpBody = try JSONEncoder().encode(payload)
        let data = try await data(for: request)
        return try JSONDecoder().decode([ProfileLookupRow].self, from: data)
    }

    private func addHeaders(to request: inout URLRequest, session: UserSession) {
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FriendsAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FriendsAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }
        return data
    }
}

private struct ProfileLookupRow: Decodable {
    let id: String
    let name: String?
    let handle: String?
}

private struct PendingRow: Decodable {
    let receiverId: String

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
    }
}

private struct FriendRequestRowLite: Decodable {
    let senderId: String
    let receiverId: String
    let status: String

    enum CodingKeys: String, CodingKey {
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

private struct MatchContactsPayload: Encodable {
    let hashes: [String]
}

private struct ContactHashPayload: Encodable {
    let userId: String
    let hash: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case hash
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}

enum FriendsAPIError: Error {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int)
}
