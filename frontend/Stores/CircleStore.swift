import Foundation

@MainActor
final class CircleStore: ObservableObject {
    @Published var circles: [CircleGroup] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let service: CircleService

    init(service: CircleService = CircleService()) {
        self.service = service
    }

    func load(session: UserSession) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            circles = try await service.fetchCircles(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCircle(named name: String, session: UserSession) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await service.createCircle(name: trimmed, session: session)
            await load(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameCircle(id: UUID, name: String, session: UserSession) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await service.renameCircle(id: id, name: trimmed, session: session)
            await load(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCircle(id: UUID, session: UserSession) async {
        do {
            try await service.deleteCircle(id: id, session: session)
            await load(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addMember(to circleId: UUID, friend: FriendListItem, session: UserSession) async {
        guard let userId = UUID(uuidString: friend.id) else { return }
        do {
            try await service.addMember(circleId: circleId, userId: userId, session: session)
            await load(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMember(from circleId: UUID, memberId: UUID, session: UserSession) async {
        do {
            try await service.removeMember(circleId: circleId, userId: memberId, session: session)
            await load(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func circle(for id: UUID) -> CircleGroup? {
        circles.first(where: { $0.id == id })
    }
}
