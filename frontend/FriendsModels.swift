import Foundation

enum FriendshipState: String, Codable {
    case none
    case outgoingPending
    case friends
}

struct UserSearchResult: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let handle: String
    let state: FriendshipState
}

struct PublicUser: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let handle: String
}
