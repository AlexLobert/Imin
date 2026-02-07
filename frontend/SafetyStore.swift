import Foundation

@MainActor
final class SafetyStore: ObservableObject {
    @Published private(set) var blockedUserIds: Set<UserID> = []
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let service: SafetyServiceProtocol

    init(service: SafetyServiceProtocol = SafetyStore.defaultService()) {
        self.service = service
    }

    nonisolated private static func defaultService() -> SafetyServiceProtocol {
        switch AppEnvironment.backend {
        case .supabase:
            return SupabaseSafetyService()
        case .kris:
            return NoopSafetyService()
        }
    }

    func load(session: UserSession) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            blockedUserIds = try await service.fetchBlockedUserIds(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isBlocked(_ userId: UserID) -> Bool {
        blockedUserIds.contains(userId)
    }

    func block(userId: UserID, session: UserSession) async -> Bool {
        errorMessage = nil
        do {
            try await service.blockUser(blockedUserId: userId, session: session)
            blockedUserIds.insert(userId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func unblock(userId: UserID, session: UserSession) async -> Bool {
        errorMessage = nil
        do {
            try await service.unblockUser(blockedUserId: userId, session: session)
            blockedUserIds.remove(userId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func report(
        threadId: String,
        messageId: String?,
        reportedUserId: UserID?,
        reason: String,
        details: String?,
        session: UserSession
    ) async -> Bool {
        errorMessage = nil
        do {
            try await service.createReport(
                threadId: threadId,
                messageId: messageId,
                reportedUserId: reportedUserId,
                reason: reason,
                details: details,
                session: session
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private struct NoopSafetyService: SafetyServiceProtocol {
    func fetchBlockedUserIds(session: UserSession) async throws -> Set<UserID> {
        []
    }

    func blockUser(blockedUserId: UserID, session: UserSession) async throws {
        // no-op
    }

    func unblockUser(blockedUserId: UserID, session: UserSession) async throws {
        // no-op
    }

    func createReport(
        threadId: String,
        messageId: String?,
        reportedUserId: UserID?,
        reason: String,
        details: String?,
        session: UserSession
    ) async throws {
        // no-op
    }
}

