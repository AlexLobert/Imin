import Foundation

enum UserStatus: String, CaseIterable, Codable {
    case `in` = "In"
    case out = "Out"

    var label: String {
        rawValue
    }
}

struct UserPreview: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let status: UserStatus
    let avatarSystemName: String?

    init(id: UUID = UUID(), name: String, status: UserStatus, avatarSystemName: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.avatarSystemName = avatarSystemName
    }
}
