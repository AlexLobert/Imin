import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var store = FriendsStore(api: FriendsAPIClient())

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add Friends")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)
                        .padding(.top, 6)

                    searchBar

                    inviteButton
                    contactsButton

                    resultsSection

                    if !store.contactMatches.isEmpty {
                        contactsSection
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search by @handle", text: $store.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: store.searchQuery) { _, newValue in
                    store.onSearchQueryChanged(newValue) {
                        await sessionManager.validSession()
                    }
                }

            if store.isSearching {
                ProgressView().scaleEffect(0.9)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    private var inviteButton: some View {
        Button {
            let url = URL(string: "https://imin.example/invite?ref=YOURCODE")!
            InviteManager.presentInviteShareSheet(referralURL: url)
        } label: {
            HStack {
                Image(systemName: "paperplane")
                Text("Invite friends")
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.systemMint).opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var contactsButton: some View {
        Button {
            Task { await store.matchFromContacts { await sessionManager.validSession() } }
        } label: {
            HStack {
                Image(systemName: "person.2")
                Text("Find friends from contacts")
                    .font(.body.weight(.semibold))
                Spacer()
                if store.isMatchingContacts {
                    ProgressView().scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("People")
                .font(.headline.weight(.semibold))

            if store.searchResults.isEmpty {
                Text("Type at least 2 characters to search.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.searchResults) { user in
                        userRow(user)
                    }
                }
            }
        }
    }

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From Contacts")
                .font(.headline.weight(.semibold))

            VStack(spacing: 10) {
                ForEach(store.contactMatches) { user in
                    userRow(user)
                }
            }
        }
    }

    private func userRow(_ user: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
                .overlay(Text(initials(user.name)).font(.subheadline.weight(.bold)))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.body.weight(.semibold))
                Text("@\(user.handle)").font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()
            actionPill(for: user)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    @ViewBuilder
    private func actionPill(for user: UserSearchResult) -> some View {
        switch user.state {
        case .none:
            Button("Add") {
                Task { await store.addFriend(userId: user.id) { await sessionManager.validSession() } }
            }
            .buttonStyle(.borderedProminent)
        case .outgoingPending:
            Text("Pending")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
        case .friends:
            Text("Friend")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.systemMint))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let a = parts.first?.first.map(String.init) ?? ""
        let b = parts.dropFirst().first?.first.map(String.init) ?? ""
        let s = (a + b).uppercased()
        return s.isEmpty ? "U" : s
    }
}
