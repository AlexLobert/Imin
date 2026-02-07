import Foundation
import SwiftUI

@MainActor
final class FriendsStore: ObservableObject {
    let api: FriendsAPI

    @Published var searchQuery: String = ""
    @Published var searchResults: [UserSearchResult] = []
    @Published var contactMatches: [UserSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var isMatchingContacts: Bool = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    init(api: FriendsAPI) {
        self.api = api
    }

    func onSearchQueryChanged(_ q: String, sessionProvider: @escaping () async -> UserSession?) {
        searchTask?.cancel()

        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            do {
                isSearching = true
                try await Task.sleep(nanoseconds: 250_000_000)
                guard let session = await sessionProvider() else {
                    isSearching = false
                    return
                }
                let results = try await api.searchUsers(query: trimmed, session: session)
                if !Task.isCancelled {
                    self.searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Search failed. Please try again."
                }
            }
            self.isSearching = false
        }
    }

    func addFriend(userId: String, sessionProvider: @escaping () async -> UserSession?) async {
        do {
            guard let session = await sessionProvider() else { return }
            try await api.sendFriendRequest(to: userId, session: session)

            if let idx = searchResults.firstIndex(where: { $0.id == userId }) {
                let u = searchResults[idx]
                searchResults[idx] = UserSearchResult(id: u.id, name: u.name, handle: u.handle, state: .outgoingPending)
            }
            if let idx = contactMatches.firstIndex(where: { $0.id == userId }) {
                let u = contactMatches[idx]
                contactMatches[idx] = UserSearchResult(id: u.id, name: u.name, handle: u.handle, state: .outgoingPending)
            }
        } catch {
            errorMessage = "Couldn’t send request."
        }
    }

    func matchFromContacts(sessionProvider: @escaping () async -> UserSession?) async {
        do {
            isMatchingContacts = true
            let granted = await ContactsMatcher.requestAccess()
            guard granted else {
                errorMessage = "Contacts access is required to find friends from contacts."
                isMatchingContacts = false
                return
            }

            let hashes = try await Task.detached(priority: .userInitiated) {
                try ContactsMatcher.loadHashedIdentifiers()
            }.value
            guard let session = await sessionProvider() else {
                isMatchingContacts = false
                return
            }
            try await api.uploadContactHashes(hashes: hashes, session: session)
            let matches = try await api.matchContacts(hashes: hashes, session: session)
            self.contactMatches = matches
        } catch {
            errorMessage = "Couldn’t match contacts."
        }
        isMatchingContacts = false
    }
}
