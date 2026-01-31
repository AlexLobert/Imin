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
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
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

    func setStatus(_ newStatus: UserStatus) {
        let previous = status
        status = newStatus

        Task {
            do {
                try await apiClient.setStatus(newStatus)
            } catch {
                status = previous
                errorMessage = error.localizedDescription
            }
        }
    }

}
