import SwiftUI

struct InNowRowView: View {
    let users: [UserPreview]
    let onSelect: (UserPreview) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In Now")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ConnectColors.textPrimary)

            if users.isEmpty {
                Text("No one's in yet — be the first.")
                    .font(.system(size: 15))
                    .foregroundColor(ConnectColors.textSecondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(users) { user in
                            Button {
                                onSelect(user)
                            } label: {
                                VStack(spacing: 8) {
                                    AvatarView(
                                        name: user.name,
                                        systemImage: user.avatarSystemName,
                                        showsStatus: true,
                                        isOnline: user.status == .in
                                    )
                                    Text(user.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(ConnectColors.textPrimary)
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}
