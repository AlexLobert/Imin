import Foundation

enum AvailabilityState: String, Codable, CaseIterable {
    case inOffice = "in"
    case out = "out"

    var label: String {
        switch self {
        case .inOffice:
            return "In"
        case .out:
            return "Out"
        }
    }
}

struct Availability: Codable, Equatable {
    let userId: String
    let state: AvailabilityState
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case state
        case expiresAt = "expires_at"
    }
}
