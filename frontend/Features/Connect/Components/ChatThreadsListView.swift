import SwiftUI

struct ChatThreadsListView: View {
    let threads: [ChatThread]
    let onSelect: (ChatThread) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                Button {
                    onSelect(thread)
                } label: {
                    ChatRowView(thread: thread)
                }
                .buttonStyle(.plain)

                if index < threads.count - 1 {
                    Divider()
                        .background(ConnectColors.divider)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct ChatThreadsListView_Previews: PreviewProvider {
    static var previews: some View {
        let user = UserPreview(name: "Ava", status: .in)
        let threads = [
            ChatThread(
                id: UUID().uuidString,
                title: "Ava",
                participantId: "",
                lastMessage: "Want to grab coffee?",
                updatedAt: Date(),
                participants: [user],
                unreadCount: 2,
                inCount: 1
            )
        ]

        ChatThreadsListView(threads: threads) { _ in }
            .padding()
            .background(ConnectColors.background)
            .previewLayout(.sizeThatFits)
    }
}
