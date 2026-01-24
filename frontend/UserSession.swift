import Foundation

struct UserSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let expiresAt: Date
}
