import SwiftUI

struct PlusActionSheet: ViewModifier {
    @Binding var isPresented: Bool
    let friends: [FriendListItem]
    let onNewChat: (FriendListItem) -> Void
    let onNewCircle: (String) -> Void
    let onFriends: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PlusCreateSheet(
                    friends: friends,
                    onCreateChat: { text in
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard let match = PlusCreateSheet.bestMatch(in: friends, for: trimmed) else { return }
                        onNewChat(match)
                        isPresented = false
                    },
                    onSelectFriend: { friend in
                        onNewChat(friend)
                        isPresented = false
                    },
                    onCreateCircle: { text in
                        onNewCircle(text)
                        isPresented = false
                    },
                    onFriends: {
                        onFriends()
                        isPresented = false
                    },
                    onCancel: { isPresented = false }
                )
                .glassSheetStyle()
            }
    }
}

extension View {
    func plusActionSheet(
        isPresented: Binding<Bool>,
        friends: [FriendListItem],
        onNewChat: @escaping (FriendListItem) -> Void,
        onNewCircle: @escaping (String) -> Void,
        onFriends: @escaping () -> Void
    ) -> some View {
        modifier(PlusActionSheet(
            isPresented: isPresented,
            friends: friends,
            onNewChat: onNewChat,
            onNewCircle: onNewCircle,
            onFriends: onFriends
        ))
    }
}

private struct PlusCreateSheet: View {
    @State private var chatTarget = ""
    @State private var circleName = ""
    let friends: [FriendListItem]

    let onCreateChat: (String) -> Void
    let onSelectFriend: (FriendListItem) -> Void
    let onCreateCircle: (String) -> Void
    let onFriends: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("Create")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 14) {
                glassSection(
                    title: "New Chat",
                    placeholder: "Email or username",
                    text: $chatTarget,
                    systemName: "person.crop.circle.badge.plus",
                    actionTitle: "Start",
                    action: { onCreateChat(chatTarget) }
                )

                if !chatTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let matches = filteredFriends
                    if matches.isEmpty {
                        Text("No matching friends.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignColors.textSecondary)
                            .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(matches) { friend in
                                Button {
                                    onSelectFriend(friend)
                                } label: {
                                    HStack(spacing: 12) {
                                        AvatarView(name: friend.name, systemImage: "person.fill")
                                            .frame(width: 36, height: 36)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(DesignColors.textPrimary)
                                                .lineLimit(1)
                                            Text(friend.handle)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(DesignColors.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(DesignColors.textSecondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .glassCardStyle(cornerRadius: 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                glassSection(
                    title: "New Circle",
                    placeholder: "Name your circle",
                    text: $circleName,
                    systemName: "person.2.circle",
                    actionTitle: "Create",
                    action: { onCreateCircle(circleName) }
                )

                Button(action: onFriends) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppStyle.mint)

                        Text("Add / View Friends")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignColors.textPrimary)

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassCardStyle(cornerRadius: 18)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func glassSection(
        title: String,
        placeholder: String,
        text: Binding<String>,
        systemName: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppStyle.mint)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
            }

            HStack(spacing: 10) {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.35))
                    )

                Button(actionTitle) {
                    action()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.66, green: 0.9, blue: 0.81),
                                    Color(red: 0.5, green: 0.85, blue: 0.75)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCardStyle(cornerRadius: 20)
    }

    private var filteredFriends: [FriendListItem] {
        let query = chatTarget.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return friends.filter { friend in
            friend.name.lowercased().contains(query) || friend.handle.lowercased().contains(query)
        }
    }

    static func bestMatch(in friends: [FriendListItem], for query: String) -> FriendListItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if let exact = friends.first(where: { $0.handle.lowercased() == lowered || $0.name.lowercased() == lowered }) {
            return exact
        }
        return friends.first(where: { $0.name.lowercased().contains(lowered) || $0.handle.lowercased().contains(lowered) })
    }
}
