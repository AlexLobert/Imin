import SwiftUI

@MainActor
final class PrivacyStore: ObservableObject {
    @AppStorage("privacy.searchableByHandle") var searchableByHandle: Bool = true

    private let config: SupabaseConfig
    private let urlSession: URLSession

    init(config: SupabaseConfig = .default, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func setSearchableByHandle(_ value: Bool, session: UserSession) async throws {
        let previous = searchableByHandle
        searchableByHandle = value

        do {
            try await persistSearchableByHandle(value, session: session)
        } catch {
            searchableByHandle = previous
            throw error
        }
    }

    private func persistSearchableByHandle(_ value: Bool, session: UserSession) async throws {
        let url = config.url.appendingPathComponent("/rest/v1/rpc/set_searchable_by_handle")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SearchableByHandlePayload(value: value))

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PrivacyStoreError.requestFailed
        }
    }
}

private struct SearchableByHandlePayload: Encodable {
    let value: Bool

    enum CodingKeys: String, CodingKey {
        case value = "p_value"
    }
}

enum PrivacyStoreError: Error {
    case requestFailed
}
