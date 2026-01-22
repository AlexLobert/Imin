import Foundation

typealias UserID = String

enum ChatAudienceMode: String {
    case everyone
    case circles
}

struct InUser: Identifiable, Equatable, Hashable {
    let id: UserID
    let name: String
    let handle: String
}

struct ChatThread: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let participantId: UserID
    let lastMessage: String?
    let updatedAt: Date
}

struct ChatMessage: Identifiable, Equatable, Hashable {
    let id: String
    let threadId: String
    let senderId: UserID
    let body: String
    let createdAt: Date
}
