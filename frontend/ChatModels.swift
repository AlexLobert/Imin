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
    let participants: [UserPreview]
    let unreadCount: Int
    let inCount: Int

    var timestamp: Date {
        updatedAt
    }

    init(
        id: String,
        title: String,
        participantId: UserID,
        lastMessage: String?,
        updatedAt: Date,
        participants: [UserPreview] = [],
        unreadCount: Int = 0,
        inCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.participantId = participantId
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.participants = participants
        self.unreadCount = unreadCount
        self.inCount = inCount
    }
}

struct ChatMessage: Identifiable, Equatable, Hashable {
    let id: String
    let threadId: String
    let senderId: UserID
    let body: String
    let createdAt: Date
}
