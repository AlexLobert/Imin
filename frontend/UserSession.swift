import Foundation

struct UserSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String?
    let expiresAt: Date

    func withEmail(_ email: String?) -> UserSession {
        UserSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            email: email,
            expiresAt: expiresAt
        )
    }
}

extension UserSession {
    static func kris(email: String) -> UserSession {
        let farFuture = Date().addingTimeInterval(60 * 60 * 24 * 365)
        return UserSession(
            accessToken: "kris-session",
            refreshToken: "kris-session",
            userId: email,
            email: email,
            expiresAt: farFuture
        )
    }
}
