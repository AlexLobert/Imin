import SwiftUI

struct ChatRowView: View {
    let thread: ChatThread
    private var isGroup: Bool {
        thread.participants.count > 1 || thread.inCount > 1
    }

    var body: some View {
        HStack(spacing: 12) {
            ChatAvatarView(title: thread.title, participants: thread.participants, isGroup: isGroup)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(thread.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ConnectColors.textPrimary)

                    if thread.inCount > 0 {
                        Text("\(thread.inCount) In")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule()
                                    .fill(ConnectColors.accentGreen.opacity(0.18))
                            )
                            .foregroundColor(ConnectColors.accentGreen)
                    }

                    Spacer()

                    Text(TimeFormatter.shared.string(from: thread.updatedAt))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ConnectColors.textSecondary.opacity(0.7))
                }

                HStack {
                    Text(thread.lastMessage ?? "Say hi")
                        .font(.system(size: 13))
                        .foregroundColor(ConnectColors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(ConnectColors.accentGreen))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ChatAvatarView: View {
    let title: String
    let participants: [UserPreview]
    let isGroup: Bool

    var body: some View {
        ZStack {
            if participants.count > 1 {
                CollageAvatarView(participants: participants, gradientKey: title)
            } else if isGroup {
                GroupAvatarView(gradientKey: title)
            } else {
                SingleAvatarView(title: title, user: participants.first)
            }
        }
        .frame(width: 52, height: 52)
    }
}

private struct SingleAvatarView: View {
    let title: String
    let user: UserPreview?

    var body: some View {
        Circle()
            .fill(AvatarGradient.gradient(for: title))
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(ConnectColors.chipBorder, lineWidth: 1)
            )
            .overlay(
                Group {
                    if let systemName = user?.avatarSystemName {
                        Image(systemName: systemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ConnectColors.textSecondary)
                    } else {
                        Text(initials(from: title))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ConnectColors.textPrimary)
                            .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                    }
                }
            )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

private struct CollageAvatarView: View {
    let participants: [UserPreview]
    let gradientKey: String

    var body: some View {
        ZStack {
            Circle()
                .fill(AvatarGradient.gradient(for: gradientKey))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(ConnectColors.chipBorder, lineWidth: 1)
                )

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    CollageCircle(user: participants.first)
                    CollageCircle(user: participants.dropFirst().first)
                }

                HStack(spacing: 4) {
                    CollageCircle(user: participants.dropFirst(2).first)
                    CollageCircle(user: participants.dropFirst(3).first)
                }
            }
        }
    }
}

private struct CollageCircle: View {
    let user: UserPreview?

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.85))
            .frame(width: 14, height: 14)
            .overlay(
                Group {
                    if let systemName = user?.avatarSystemName {
                        Image(systemName: systemName)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(ConnectColors.textSecondary)
                    } else if let name = user?.name {
                        Text(initials(from: name))
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(ConnectColors.textPrimary)
                    }
                }
            )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

private struct GroupAvatarView: View {
    let gradientKey: String

    var body: some View {
        Circle()
            .fill(AvatarGradient.gradient(for: gradientKey))
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(ConnectColors.chipBorder, lineWidth: 1)
            )
            .overlay(
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ConnectColors.textPrimary)
            )
    }
}

private final class TimeFormatter {
    static let shared = TimeFormatter()

    private let formatter: DateFormatter

    private init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        self.formatter = formatter
    }

    func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
