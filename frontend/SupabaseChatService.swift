import Foundation

struct SupabaseChatService: ChatServiceProtocol {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func fetchInUsers(session: UserSession) async throws -> [InUser] {
        let visibleUrl = try makeUrl(
            path: "/rest/v1/rpc/get_visible_in_users",
            queryItems: []
        )

        var visibleRequest = URLRequest(url: visibleUrl)
        visibleRequest.httpMethod = "POST"
        addHeaders(to: &visibleRequest, session: session)
        visibleRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        visibleRequest.httpBody = "{}".data(using: .utf8)
        let visibleData = try await data(for: visibleRequest)
        let visibleRows = try makeDecoder().decode([VisibleUserRow].self, from: visibleData)

        let userIds = visibleRows
            .map { $0.userId }
            .filter { $0 != session.userId }

        guard !userIds.isEmpty else { return [] }

        let profilesUrl = try makeUrl(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,handle"),
                URLQueryItem(name: "id", value: "in.(\(userIds.joined(separator: ",")))")
            ]
        )

        var profilesRequest = URLRequest(url: profilesUrl)
        profilesRequest.httpMethod = "GET"
        addHeaders(to: &profilesRequest, session: session)
        let profilesData = try await data(for: profilesRequest)
        let profiles = try makeDecoder().decode([ProfileRow].self, from: profilesData)

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return userIds.map { userId in
            let profile = profileMap[userId]
            let name = profile?.name ?? profile?.handle ?? shortId(userId)
            let handle = profile?.handle ?? "@imin"
            return InUser(id: userId, name: name, handle: handle)
        }
    }

    func fetchThreads(session: UserSession) async throws -> [ChatThread] {
        let membersUrl = try makeUrl(
            path: "/rest/v1/thread_members",
            queryItems: [
                URLQueryItem(name: "select", value: "thread_id,threads(id,title,updated_at)"),
                URLQueryItem(name: "user_id", value: "eq.\(session.userId)")
            ]
        )

        var membersRequest = URLRequest(url: membersUrl)
        membersRequest.httpMethod = "GET"
        addHeaders(to: &membersRequest, session: session)
        let membersData = try await data(for: membersRequest)
        let threadMemberships = try makeDecoder().decode([ThreadMembershipRow].self, from: membersData)

        let threads = threadMemberships.compactMap { $0.thread }
        guard !threads.isEmpty else { return [] }

        let threadIds = threads.map { $0.id }
        let lastMessages = try await fetchLastMessages(threadIds: threadIds, session: session)
        let participantMap = try await fetchParticipants(threadIds: threadIds, session: session)

        return threads.map { thread in
            let participants = participantMap[thread.id, default: []].map { profile in
                UserPreview(
                    id: UUID(uuidString: profile.id) ?? UUID(),
                    name: profile.name ?? profile.handle ?? "Chat",
                    status: .out
                )
            }
            let title = resolvedTitle(threadTitle: thread.title, participants: participants)
            return ChatThread(
                id: thread.id,
                title: title,
                participantId: participantMap[thread.id]?.first?.id ?? "",
                lastMessage: lastMessages[thread.id]?.body,
                updatedAt: thread.updatedAt,
                participants: participants
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchMessages(threadId: String, session: UserSession) async throws -> [ChatMessage] {
        let url = try makeUrl(
            path: "/rest/v1/messages",
            queryItems: [
                URLQueryItem(name: "select", value: "id,thread_id,sender_id,body,created_at"),
                URLQueryItem(name: "thread_id", value: "eq.\(threadId)"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let data = try await data(for: request)
        let rows = try makeDecoder().decode([MessageRow].self, from: data)
        return rows.map { $0.toMessage() }
    }

    func openOrCreateThread(with user: InUser, session: UserSession) async throws -> ChatThread {
        if let existing = try await findThread(with: user, session: session) {
            return existing
        }

        let threadId = try await createThreadWithMember(userId: user.id, session: session)
        let newThread = try await fetchThread(threadId: threadId, session: session)
        let title = newThread.title ?? user.name

        return ChatThread(
            id: newThread.id,
            title: title,
            participantId: user.id,
            lastMessage: nil,
            updatedAt: newThread.updatedAt
        )
    }

    func sendMessage(threadId: String, body: String, session: UserSession) async throws -> ChatMessage {
        let messageUrl = try makeUrl(path: "/rest/v1/messages", queryItems: [])
        var messageRequest = URLRequest(url: messageUrl)
        messageRequest.httpMethod = "POST"
        addHeaders(to: &messageRequest, session: session)
        messageRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        messageRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
        messageRequest.httpBody = try JSONEncoder().encode([
            NewMessageRow(threadId: threadId, senderId: session.userId, body: body)
        ])

        let messageData = try await data(for: messageRequest)
        let messageRows = try makeDecoder().decode([MessageRow].self, from: messageData)
        guard let message = messageRows.first else {
            throw SupabaseChatError.emptyResponse
        }

        try await updateThreadTimestamp(threadId: threadId, session: session)

        return message.toMessage()
    }

    func deleteThread(threadId: String, session: UserSession) async throws {
        let url = try makeUrl(
            path: "/rest/v1/thread_members",
            queryItems: [
                URLQueryItem(name: "thread_id", value: "eq.\(threadId)"),
                URLQueryItem(name: "user_id", value: "eq.\(session.userId)")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request, session: session)

        _ = try await data(for: request)
    }

    private func findThread(with user: InUser, session: UserSession) async throws -> ChatThread? {
        let url = try makeUrl(
            path: "/rest/v1/thread_members",
            queryItems: [
                URLQueryItem(name: "select", value: "thread_id,user_id"),
                URLQueryItem(name: "user_id", value: "in.(\(session.userId),\(user.id))")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let responseData = try await data(for: request)
        let rows = try makeDecoder().decode([ThreadMemberRow].self, from: responseData)

        var counts: [String: Set<String>] = [:]
        for row in rows {
            counts[row.threadId, default: []].insert(row.userId)
        }

        guard let threadId = counts.first(where: { $0.value.contains(session.userId) && $0.value.contains(user.id) })?.key else {
            return nil
        }

        let threadUrl = try makeUrl(
            path: "/rest/v1/threads",
            queryItems: [
                URLQueryItem(name: "select", value: "id,title,updated_at"),
                URLQueryItem(name: "id", value: "eq.\(threadId)")
            ]
        )

        var threadRequest = URLRequest(url: threadUrl)
        threadRequest.httpMethod = "GET"
        addHeaders(to: &threadRequest, session: session)
        let threadData = try await data(for: threadRequest)
        let threadRows = try makeDecoder().decode([ThreadRow].self, from: threadData)
        guard let thread = threadRows.first else { return nil }

        return ChatThread(
            id: thread.id,
            title: thread.title ?? user.name,
            participantId: user.id,
            lastMessage: nil,
            updatedAt: thread.updatedAt
        )
    }

    private func fetchLastMessages(threadIds: [String], session: UserSession) async throws -> [String: MessageRow] {
        let url = try makeUrl(
            path: "/rest/v1/messages",
            queryItems: [
                URLQueryItem(name: "select", value: "id,thread_id,sender_id,body,created_at"),
                URLQueryItem(name: "thread_id", value: "in.(\(threadIds.joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let responseData = try await data(for: request)
        let rows = try makeDecoder().decode([MessageRow].self, from: responseData)

        var map: [String: MessageRow] = [:]
        for row in rows {
            if map[row.threadId] == nil {
                map[row.threadId] = row
            }
        }
        return map
    }

    private func fetchParticipants(threadIds: [String], session: UserSession) async throws -> [String: [ProfileRow]] {
        let url = try makeUrl(
            path: "/rest/v1/thread_members",
            queryItems: [
                URLQueryItem(name: "select", value: "thread_id,user_id"),
                URLQueryItem(name: "thread_id", value: "in.(\(threadIds.joined(separator: ",")))"),
                URLQueryItem(name: "user_id", value: "neq.\(session.userId)")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let responseData = try await data(for: request)
        let rows = try makeDecoder().decode([ThreadMemberRow].self, from: responseData)

        let userIds = Set(rows.map { $0.userId })
        guard !userIds.isEmpty else { return [:] }

        let profileUrl = try makeUrl(
            path: "/rest/v1/profiles",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,handle"),
                URLQueryItem(name: "id", value: "in.(\(userIds.joined(separator: ",")))")
            ]
        )

        var profileRequest = URLRequest(url: profileUrl)
        profileRequest.httpMethod = "GET"
        addHeaders(to: &profileRequest, session: session)
        let profileData = try await data(for: profileRequest)
        let profiles = try makeDecoder().decode([ProfileRow].self, from: profileData)
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        var map: [String: [ProfileRow]] = [:]
        for row in rows {
            if let profile = profileMap[row.userId] {
                map[row.threadId, default: []].append(profile)
            }
        }
        return map
    }

    private func createThreadWithMember(userId: String, session: UserSession) async throws -> String {
        let url = try makeUrl(path: "/rest/v1/rpc/create_thread_with_member", queryItems: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "other_user": userId,
            "title": nil as String?
        ])

        let data = try await data(for: request)
        if let threadId = try? JSONDecoder().decode(String.self, from: data) {
            return threadId
        }
        if let threadIds = try? JSONDecoder().decode([String].self, from: data), let threadId = threadIds.first {
            return threadId
        }
        if let response = try? JSONDecoder().decode(ThreadIdResponse.self, from: data), let threadId = response.threadId {
            return threadId
        }
        if let responses = try? JSONDecoder().decode([ThreadIdResponse].self, from: data), let threadId = responses.first?.threadId {
            return threadId
        }
        throw SupabaseChatError.emptyResponse
    }

    private func fetchThread(threadId: String, session: UserSession) async throws -> ThreadRow {
        let url = try makeUrl(
            path: "/rest/v1/threads",
            queryItems: [
                URLQueryItem(name: "select", value: "id,title,updated_at"),
                URLQueryItem(name: "id", value: "eq.\(threadId)")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let data = try await data(for: request)
        let threadRows = try makeDecoder().decode([ThreadRow].self, from: data)
        guard let thread = threadRows.first else {
            throw SupabaseChatError.emptyResponse
        }
        return thread
    }

    private func updateThreadTimestamp(threadId: String, session: UserSession) async throws {
        let url = try makeUrl(
            path: "/rest/v1/threads",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(threadId)")
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try makeEncoder().encode(["updated_at": Date()])

        _ = try await data(for: request)
    }

    private func makeUrl(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: config.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw SupabaseChatError.invalidUrl
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
            throw SupabaseChatError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            throw SupabaseChatError.requestFailed(statusCode: httpResponse.statusCode, message: message)
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

    private func shortId(_ id: String) -> String {
        String(id.prefix(6))
    }

    private func resolvedTitle(threadTitle: String?, participants: [UserPreview]) -> String {
        let cleaned = threadTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleaned.isEmpty, cleaned.lowercased() != "chat" {
            return cleaned
        }
        if let name = participants.first?.name, !name.isEmpty {
            return name
        }
        return "Chat"
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
}

private struct VisibleUserRow: Decodable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

private struct ProfileRow: Decodable {
    let id: String
    let name: String?
    let handle: String?
}

private struct ThreadMembershipRow: Decodable {
    let threadId: String
    let thread: ThreadRow?

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case thread = "threads"
    }
}

private struct ThreadRow: Decodable {
    let id: String
    let title: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
    }
}

private struct ThreadIdResponse: Decodable {
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case threadId = "create_thread_with_member"
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        threadId = try container.decodeIfPresent(String.self, forKey: .threadId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
    }
}

private struct NewThreadRow: Encodable {
    let title: String?
}

private struct ThreadMemberRow: Codable {
    let threadId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case userId = "user_id"
    }
}

private struct MessageRow: Decodable {
    let id: String
    let threadId: String
    let senderId: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case senderId = "sender_id"
        case body
        case createdAt = "created_at"
    }

    func toMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            threadId: threadId,
            senderId: senderId,
            body: body,
            createdAt: createdAt
        )
    }
}

private struct NewMessageRow: Encodable {
    let threadId: String
    let senderId: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case senderId = "sender_id"
        case body
    }
}

enum SupabaseChatError: Error {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case emptyResponse
}

extension SupabaseChatError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid chat URL"
        case .invalidResponse:
            return "Invalid response from chat service"
        case let .requestFailed(statusCode, message):
            return "Chat error (\(statusCode)): \(message)"
        case .emptyResponse:
            return "No data returned from chat service"
        }
    }
}
