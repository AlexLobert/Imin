import Foundation

@MainActor
final class ChatStore: ObservableObject {
    @Published var inUsers: [InUser] = []
    @Published var threads: [ChatThread] = []
    @Published var messagesByThread: [String: [ChatMessage]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: ChatServiceProtocol

    init(service: ChatServiceProtocol = SupabaseChatService()) {
        self.service = service
    }

    var unreadTotal: Int {
        threads.reduce(0) { total, thread in
            total + max(thread.unreadCount, 0)
        }
    }

    func load(session: UserSession) async {
        guard AppEnvironment.isChatBackendEnabled else {
            isLoading = false
            errorMessage = nil
            inUsers = []
            threads = []
            messagesByThread = [:]
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            inUsers = try await service.fetchInUsers(session: session)
            threads = try await service.fetchThreads(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openThread(for user: InUser, session: UserSession) async -> ChatThread? {
        guard AppEnvironment.isChatBackendEnabled else { return nil }
        do {
            let thread = try await service.openOrCreateThread(with: user, session: session)
            await refreshThreads(session: session)
            return thread
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadMessages(for thread: ChatThread, session: UserSession) async {
        guard AppEnvironment.isChatBackendEnabled else { return }
        do {
            let messages = try await service.fetchMessages(threadId: thread.id, session: session)
            messagesByThread[thread.id] = messages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMessage(in thread: ChatThread, body: String, session: UserSession) async {
        guard AppEnvironment.isChatBackendEnabled else { return }
        do {
            let message = try await service.sendMessage(threadId: thread.id, body: body, session: session)
            messagesByThread[thread.id, default: []].append(message)
            await refreshThreads(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func messages(for thread: ChatThread) -> [ChatMessage] {
        messagesByThread[thread.id, default: []]
    }

    private func refreshThreads(session: UserSession) async {
        guard AppEnvironment.isChatBackendEnabled else { return }
        do {
            threads = try await service.fetchThreads(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
