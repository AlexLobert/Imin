import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chatStore: ChatStore
    @State private var path: [ChatThread] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Chat")
                            .font(.custom("Avenir Next", size: 24))
                            .fontWeight(.heavy)

                        inNowSection

                        threadsSection

                        if let errorMessage = chatStore.errorMessage {
                            Text(errorMessage)
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundColor(.black.opacity(0.7))
                        }
                    }
                    .padding(24)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("In now")
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chatStore.inUsers) { user in
                        Button(action: {
                            Task {
                                if let session = await sessionManager.validSession(),
                                   let thread = await chatStore.openThread(for: user, session: session) {
                                    path.append(thread)
                                }
                            }
                        }) {
                            VStack(spacing: 6) {
                                Text(user.name)
                                    .font(.custom("Avenir Next", size: 14))
                                    .fontWeight(.bold)
                                Text(user.handle)
                                    .font(.custom("Avenir Next", size: 11))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                            .cornerRadius(16)
                        }
                        .foregroundColor(.black)
                    }
                }
            }

            if chatStore.inUsers.isEmpty {
                Text("No one is in yet. Be the spark.")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundColor(.black.opacity(0.7))
            }
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.95, blue: 0.85))
        .cornerRadius(22)
    }

    private var threadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Threads")
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.bold)

            if chatStore.threads.isEmpty {
                Text("Start a chat from the In now list.")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundColor(.black.opacity(0.7))
            } else {
                ForEach(chatStore.threads) { thread in
                    NavigationLink(value: thread) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(thread.title)
                                    .font(.custom("Avenir Next", size: 15))
                                    .fontWeight(.bold)
                                Text(thread.lastMessage ?? "Say hey")
                                    .font(.custom("Avenir Next", size: 12))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                            Spacer()
                            Text("Open")
                                .font(.custom("Avenir Next", size: 12))
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(12)
                        .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                        .cornerRadius(16)
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }

    private func loadChatData() async {
        guard let session = await sessionManager.validSession() else { return }
        await chatStore.load(session: session)
    }
}
