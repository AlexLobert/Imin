import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chatStore: ChatStore
    @State private var path: [ChatThread] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                        HStack(spacing: 10) {
                            Image("IminLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)

                            Text("Chat")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(AppColors.subtleBackground)
                                .clipShape(Circle())
                        }

                        inNowSection

                        threadsSection

                        if let errorMessage = chatStore.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(for: ChatThread.self) { thread in
                ChatThreadView(thread: thread)
            }
            .task(id: sessionManager.session?.userId) {
                await loadChatData()
            }
        }
    }

    private var inNowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In now")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if chatStore.inUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image("IminLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .opacity(0.18)

                    Text("No one’s in yet — be the spark.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(chatStore.inUsers.enumerated()), id: \.element.id) { index, user in
                        Button(action: {
                            Task {
                                if let session = await sessionManager.validSession(),
                                   let thread = await chatStore.openThread(for: user, session: session) {
                                    path.append(thread)
                                }
                            }
                        }) {
                            ChatPersonRow(name: user.name, subtitle: "In now", showsMessageIcon: true)
                        }
                        .buttonStyle(.plain)

                        if index < chatStore.inUsers.count - 1 {
                            Divider()
                                .background(AppColors.separator)
                        }
                    }
                }
            }
        }
    }

    private var threadsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Threads")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if chatStore.threads.isEmpty {
                Text("Start a chat from the In now list.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(chatStore.threads.enumerated()), id: \.element.id) { index, thread in
                        NavigationLink(value: thread) {
                            ChatThreadRow(name: thread.title, preview: thread.lastMessage ?? "Say hey")
                        }
                        .foregroundColor(.primary)

                        if index < chatStore.threads.count - 1 {
                            Divider()
                                .background(AppColors.separator)
                        }
                    }
                }
            }
        }
    }

    private func loadChatData() async {
        guard let session = await sessionManager.validSession() else { return }
        await chatStore.load(session: session)
    }
}

private struct ChatPersonRow: View {
    let name: String
    let subtitle: String
    var showsMessageIcon: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.avatarBackground)
                    .frame(width: 40, height: 40)

                Text(initials(from: name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if showsMessageIcon {
                Image(systemName: "message.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accentGreen)
            }
        }
        .padding(.vertical, AppSpacing.rowVertical)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

private struct ChatThreadRow: View {
    let name: String
    let preview: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.avatarBackground)
                    .frame(width: 40, height: 40)

                Text(initials(from: name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(preview)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.rowVertical)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}
