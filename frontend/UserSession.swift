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
