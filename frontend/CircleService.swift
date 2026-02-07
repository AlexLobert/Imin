import Foundation

struct CircleService {
    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func fetchCircles(session: UserSession) async throws -> [CircleGroup] {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/circles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,name,created_at"),
            URLQueryItem(name: "owner_id", value: "eq.\(session.userId)"),
            URLQueryItem(name: "order", value: "created_at.asc")
        ]

        guard let url = components?.url else { throw CircleServiceError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)
        let responseData = try await data(for: request)
        let circles = try JSONDecoder().decode([CircleRow].self, from: responseData)

        guard !circles.isEmpty else { return [] }

        let circleIds = circles.map { $0.id.uuidString }.joined(separator: ",")
        var memberComponents = URLComponents(url: config.url.appendingPathComponent("/rest/v1/circle_members"), resolvingAgainstBaseURL: false)
        memberComponents?.queryItems = [
            URLQueryItem(name: "select", value: "circle_id,user_id"),
            URLQueryItem(name: "circle_id", value: "in.(\(circleIds))")
        ]

        guard let membersUrl = memberComponents?.url else { throw CircleServiceError.invalidUrl }

        var membersRequest = URLRequest(url: membersUrl)
        membersRequest.httpMethod = "GET"
        addHeaders(to: &membersRequest, session: session)
        let membersResponse = try await data(for: membersRequest)
        let members = try JSONDecoder().decode([CircleMemberRow].self, from: membersResponse)
        let profileMap = try await fetchProfiles(ids: members.map { $0.userId }, session: session)
        let grouped = Dictionary(grouping: members, by: { $0.circleId })

        return circles.map { circle in
            let circleMembers = grouped[circle.id, default: []].map { row in
                let profile = profileMap[row.userId.uuidString.lowercased()]
                let name = profile?.name ?? profile?.handle ?? shortId(row.userId.uuidString)
                return CircleMember(id: row.userId, name: name, handle: profile?.handle)
            }
            return CircleGroup(id: circle.id, name: circle.name, members: circleMembers)
        }
    }

    func createCircle(name: String, session: UserSession) async throws -> CircleGroup {
        let url = config.url.appendingPathComponent("/rest/v1/circles")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = CreateCirclePayload(ownerId: session.userId, name: name)
        request.httpBody = try JSONEncoder().encode([payload])

        let responseData = try await data(for: request)
        let circles = try JSONDecoder().decode([CircleRow].self, from: responseData)
        guard let circle = circles.first else { throw CircleServiceError.emptyResponse }
        return CircleGroup(id: circle.id, name: circle.name, members: [])
    }

    func renameCircle(id: UUID, name: String, session: UserSession) async throws {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/circles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]

        guard let url = components?.url else { throw CircleServiceError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UpdateCirclePayload(name: name))

        _ = try await data(for: request)
    }

    func deleteCircle(id: UUID, session: UserSession) async throws {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/circles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)")
        ]

        guard let url = components?.url else { throw CircleServiceError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request, session: session)

        _ = try await data(for: request)
    }

    func addMember(circleId: UUID, userId: UUID, session: UserSession) async throws {
        let url = config.url.appendingPathComponent("/rest/v1/circle_members")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, session: session)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = CircleMemberPayload(circleId: circleId, userId: userId)
        request.httpBody = try JSONEncoder().encode([payload])

        _ = try await data(for: request)
    }

    func removeMember(circleId: UUID, userId: UUID, session: UserSession) async throws {
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/circle_members"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "circle_id", value: "eq.\(circleId.uuidString)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)")
        ]

        guard let url = components?.url else { throw CircleServiceError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request, session: session)

        _ = try await data(for: request)
    }

    private func addHeaders(to request: inout URLRequest, session: UserSession) {
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CircleServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data)
            throw CircleServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
        return data
    }

    private func decodeErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String {
                return message
            }
            if let error = json["error"] as? String {
                return error
            }
        }
        return "Request failed"
    }

    private func fetchProfiles(ids: [UUID], session: UserSession) async throws -> [String: CircleProfileRow] {
        let uniqueIds = Array(Set(ids.map(\.uuidString)))
        guard !uniqueIds.isEmpty else { return [:] }
        let joined = uniqueIds.joined(separator: ",")
        var components = URLComponents(url: config.url.appendingPathComponent("/rest/v1/profiles"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,name,handle"),
            URLQueryItem(name: "id", value: "in.(\(joined))")
        ]

        guard let url = components?.url else { throw CircleServiceError.invalidUrl }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request, session: session)

        let responseData = try await data(for: request)
        let profiles = try JSONDecoder().decode([CircleProfileRow].self, from: responseData)
        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id.lowercased(), $0) })
    }

    private func shortId(_ id: String) -> String {
        let trimmed = id.replacingOccurrences(of: "-", with: "")
        return String(trimmed.prefix(6))
    }
}

enum CircleServiceError: Error, LocalizedError {
    case invalidUrl
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid circles URL"
        case .invalidResponse:
            return "Invalid response from circles service"
        case let .requestFailed(statusCode, message):
            return "Circles error (\(statusCode)): \(message)"
        case .emptyResponse:
            return "No circle data returned"
        }
    }
}

private struct CircleRow: Decodable {
    let id: UUID
    let name: String
}

private struct CircleMemberRow: Decodable {
    let circleId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case userId = "user_id"
    }
}

private struct CircleProfileRow: Decodable {
    let id: String
    let name: String?
    let handle: String?
}

private struct CreateCirclePayload: Encodable {
    let ownerId: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case name
    }
}

private struct UpdateCirclePayload: Encodable {
    let name: String
}

private struct CircleMemberPayload: Encodable {
    let circleId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case circleId = "circle_id"
        case userId = "user_id"
    }
}
