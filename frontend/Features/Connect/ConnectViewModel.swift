import Foundation

@MainActor
final class ConnectViewModel: ObservableObject {
    enum ChatFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
    }

    @Published var status: UserStatus = .out
    @Published var selectedFilter: ChatFilter = .all
    @Published var users: [UserPreview] = []
    @Published var threads: [ChatThread] = []
    @Published var pendingRequests: [FriendRequestItem] = []
    @Published var errorMessage: String?
    @Published var isLoadingThreads = false
    @Published var isLoadingInNow = false

    private let availabilityService: AvailabilityService
    private let friendRequestService: FriendRequestService
    private let chatService: ChatServiceProtocol
    private let hiddenThreadsKey = "hiddenThreadIds"

    init(
        availabilityService: AvailabilityService = AvailabilityService(),
        friendRequestService: FriendRequestService = FriendRequestService(),
        chatService: ChatServiceProtocol = SupabaseChatService()
    ) {
        self.availabilityService = availabilityService
        self.friendRequestService = friendRequestService
        self.chatService = chatService
    }

    var inNowUsers: [UserPreview] {
        users.filter { $0.status == .in }
    }

    var filteredThreads: [ChatThread] {
        switch selectedFilter {
        case .all:
            return threads
        case .unread:
            return threads.filter { $0.unreadCount > 0 }
        }
    }

    func setStatus(
        _ newStatus: UserStatus,
        visibilityMode: AvailabilityVisibilityMode,
        visibilityCircleIds: [UUID],
        session: UserSession
    ) async {
        let previous = status
        status = newStatus
        do {
            let availabilityState = AvailabilityState(from: newStatus)
            _ = try await availabilityService.upsertAvailability(
                state: availabilityState,
                expiresAt: nil,
                visibilityMode: visibilityMode,
                visibilityCircleIds: visibilityCircleIds,
                session: session
            )
        } catch {
            status = previous
            errorMessage = error.localizedDescription
        }
    }

    func loadPendingRequests(session: UserSession) async {
        guard AppEnvironment.backend == .supabase else { return }
        do {
            pendingRequests = try await friendRequestService.fetchPendingRequests(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respondToRequest(_ request: FriendRequestItem, accept: Bool, session: UserSession) async {
        guard AppEnvironment.backend == .supabase else { return }
        do {
            let status: FriendRequestStatus = accept ? .accepted : .declined
            try await friendRequestService.updateRequestStatus(id: request.id, status: status, session: session)
            pendingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadInNowUsers(session: UserSession) async {
        guard AppEnvironment.backend == .supabase else { return }
        isLoadingInNow = true
        defer { isLoadingInNow = false }
        do {
            let inUsers = try await chatService.fetchInUsers(session: session)
            users = inUsers.map { user in
                let uuid = UUID(uuidString: user.id) ?? UUID()
                return UserPreview(id: uuid, name: user.name, status: .in)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadThreads(session: UserSession) async {
        guard AppEnvironment.backend == .supabase else { return }
        isLoadingThreads = true
        defer { isLoadingThreads = false }
        do {
            let fetched = try await chatService.fetchThreads(session: session)
            let hidden = hiddenThreadIds
            let visible = fetched.filter { !hidden.contains($0.id) }
            threads = dedupeThreads(visible)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteThread(_ thread: ChatThread, session: UserSession) async {
        guard AppEnvironment.backend == .supabase else { return }
        let previous = threads
        threads.removeAll { $0.id == thread.id }
        var hidden = hiddenThreadIds
        hidden.insert(thread.id)
        hiddenThreadIds = hidden
        do {
            try await chatService.deleteThread(threadId: thread.id, session: session)
        } catch {
            threads = previous
            hidden.remove(thread.id)
            hiddenThreadIds = hidden
            errorMessage = error.localizedDescription
        }
    }

    func thread(for user: UserPreview) -> ChatThread? {
        let userId = user.id.uuidString
        return threads.first { thread in
            if !thread.participants.isEmpty {
                return thread.participants.contains(where: { $0.id.uuidString == userId })
            }
            return thread.participantId == userId
        }
    }

}

private extension ConnectViewModel {
    var hiddenThreadIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: hiddenThreadsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: hiddenThreadsKey)
        }
    }

    func dedupeThreads(_ threads: [ChatThread]) -> [ChatThread] {
        var map: [String: ChatThread] = [:]
        for thread in threads {
            let key: String
            if !thread.participants.isEmpty {
                let ids = thread.participants.map { $0.id.uuidString }.sorted()
                key = ids.joined(separator: "|")
            } else if !thread.participantId.isEmpty {
                key = thread.participantId
            } else {
                key = thread.id
            }

            if let existing = map[key] {
                if thread.updatedAt > existing.updatedAt {
                    map[key] = thread
                }
            } else {
                map[key] = thread
            }
        }
        return map.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}

private extension AvailabilityState {
    init(from status: UserStatus) {
        switch status {
        case .in:
            self = .inOffice
        case .out:
            self = .out
        }
    }
}
