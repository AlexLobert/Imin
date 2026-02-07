import SwiftUI
import UIKit

struct InNowRowView: View {
    let users: [UserPreview]
    let isLoading: Bool
    let onSelect: (UserPreview) -> Void
    let onAddFriend: (() -> Void)?

    init(
        users: [UserPreview],
        isLoading: Bool = false,
        onSelect: @escaping (UserPreview) -> Void,
        onAddFriend: (() -> Void)? = nil
    ) {
        self.users = users
        self.isLoading = isLoading
        self.onSelect = onSelect
        self.onAddFriend = onAddFriend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In Now")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ConnectColors.textPrimary)

            if isLoading && users.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(0..<5, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                Circle()
                                    .fill(ConnectColors.muted)
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Circle()
                                            .stroke(ConnectColors.chipBorder, lineWidth: 1)
                                    )

                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(ConnectColors.muted)
                                    .frame(width: 56, height: 10)
                            }
                            .frame(width: 70, alignment: .leading)
                        }
                    }
                }
                .redacted(reason: .placeholder)
            } else if users.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Text("No one’s in right now")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ConnectColors.textSecondary)
                        .multilineTextAlignment(.center)

                    if let onAddFriend {
                        InviteFriendsEmptyCard(action: onAddFriend)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(users) { user in
                            Button {
                                onSelect(user)
                            } label: {
                                VStack(alignment: .center, spacing: 8) {
                                    AvatarView(
                                        name: user.name,
                                        systemImage: user.avatarSystemName,
                                        showsStatus: true,
                                        isOnline: user.status == .in
                                    )
                                    Text(user.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(ConnectColors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(width: 70, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }

                        if let onAddFriend {
                            AddFriendTile(action: onAddFriend)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

private struct AddFriendTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: actionWithHaptic) {
            VStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                .blendMode(.overlay)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.60),
                                    Color.white.opacity(0.06),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(Circle())
                            .blendMode(.screen)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppStyle.mint.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(AppStyle.mint)
                }
                .frame(width: 52, height: 52)

                Text("Add")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ConnectColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(width: 70, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add friend")
    }

    private func actionWithHaptic() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        action()
    }
}

private struct InviteFriendsEmptyCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: actionWithHaptic) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppStyle.mint)

                Text("Invite friends")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ConnectColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppStyle.mint.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite friends")
    }

    private func actionWithHaptic() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        action()
    }
}
