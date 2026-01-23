import Foundation

protocol ChatServiceProtocol {
    func fetchInUsers(session: UserSession) async throws -> [InUser]
    func fetchThreads(session: UserSession) async throws -> [ChatThread]
    func fetchMessages(threadId: String, session: UserSession) async throws -> [ChatMessage]
    func openOrCreateThread(with user: InUser, session: UserSession) async throws -> ChatThread
    func sendMessage(threadId: String, body: String, session: UserSession) async throws -> ChatMessage
}

actor InMemoryChatService: ChatServiceProtocol {
    private var inUsers: [InUser]
    private var threads: [ChatThread]
    private var messagesByThread: [String: [ChatMessage]]

    init() {
        let user1 = InUser(id: UUID().uuidString, name: "Ava", handle: "@ava")
        let user2 = InUser(id: UUID().uuidString, name: "Jordan", handle: "@jordan")
        let user3 = InUser(id: UUID().uuidString, name: "Maya", handle: "@maya")
        inUsers = [user1, user2, user3]

        let thread1 = ChatThread(
            id: UUID().uuidString,
            title: "Ava",
            participantId: user1.id,
            lastMessage: "Still down?",
            updatedAt: Date().addingTimeInterval(-120)
        )

        threads = [thread1]
        messagesByThread = [
            thread1.id: [
                ChatMessage(
                    id: UUID().uuidString,
                    threadId: thread1.id,
                    senderId: user1.id,
                    body: "Still down?",
                    createdAt: Date().addingTimeInterval(-120)
                )
            ]
        ]
    }

    func fetchInUsers(session: UserSession) async throws -> [InUser] {
        inUsers
    }

    func fetchThreads(session: UserSession) async throws -> [ChatThread] {
        threads.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchMessages(threadId: String, session: UserSession) async throws -> [ChatMessage] {
        messagesByThread[threadId, default: []].sorted { $0.createdAt < $1.createdAt }
    }

    func openOrCreateThread(with user: InUser, session: UserSession) async throws -> ChatThread {
        if let existing = threads.first(where: { $0.participantId == user.id }) {
            return existing
        }

        let newThread = ChatThread(
            id: UUID().uuidString,
            title: user.name,
            participantId: user.id,
            lastMessage: nil,
            updatedAt: Date()
        )
        threads.append(newThread)
        messagesByThread[newThread.id] = []
        return newThread
    }

    func sendMessage(threadId: String, body: String, session: UserSession) async throws -> ChatMessage {
        let message = ChatMessage(
            id: UUID().uuidString,
            threadId: threadId,
            senderId: session.userId,
            body: body,
            createdAt: Date()
        )

        messagesByThread[threadId, default: []].append(message)

        if let index = threads.firstIndex(where: { $0.id == threadId }) {
            let updated = ChatThread(
                id: threads[index].id,
                title: threads[index].title,
                participantId: threads[index].participantId,
                lastMessage: body,
                updatedAt: Date()
            )
            threads[index] = updated
        }

        return message
    }
}
