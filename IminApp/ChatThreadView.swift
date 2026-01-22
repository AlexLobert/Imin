import SwiftUI

struct ChatThreadView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chatStore: ChatStore
    @State private var messageText = ""

    let thread: ChatThread

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(chatStore.messages(for: thread)) { message in
                            messageRow(message)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                messageComposer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: thread.id) {
            await loadMessages()
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == sessionManager.session?.userId
        return HStack {
            if isMine { Spacer() }
            Text(message.body)
                .font(.custom("Avenir Next", size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMine ? Color(red: 0.55, green: 0.6, blue: 0.7) : Color(red: 0.98, green: 0.95, blue: 0.85))
                .foregroundColor(isMine ? .white : .black)
                .cornerRadius(16)
            if !isMine { Spacer() }
        }
    }

    private var messageComposer: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText)
                .textFieldStyle(.roundedBorder)

            Button("Send") {
                Task {
                    await sendMessage()
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }

    private func loadMessages() async {
        guard let session = sessionManager.session else { return }
        await chatStore.loadMessages(for: thread, session: session)
    }

    private func sendMessage() async {
        guard let session = sessionManager.session else { return }
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messageText = ""
        await chatStore.sendMessage(in: thread, body: trimmed, session: session)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 14))
            .fontWeight(.bold)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(red: 0.55, green: 0.6, blue: 0.7).opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}
