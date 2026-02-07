import SwiftUI

struct ChatThreadsListView: View {
    let threads: [ChatThread]
    let onSelect: (ChatThread) -> Void
    let onDelete: (ChatThread) -> Void

    var body: some View {
        let rowHeight: CGFloat = 68
        List {
            ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                VStack(spacing: 0) {
                    Button {
                        onSelect(thread)
                    } label: {
                        ChatRowView(thread: thread)
                    }
                    .buttonStyle(.plain)

                    if index < threads.count - 1 {
                        Divider()
                            .background(ConnectColors.divider)
                            .padding(.leading, 72)
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(ConnectColors.cardBackground)
                .swipeActions(edge: HorizontalEdge.trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onDelete(thread)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, rowHeight)
        .frame(height: rowHeight * CGFloat(max(threads.count, 1)))
    }
}

struct ChatThreadsSkeletonCardView: View {
    private let rowCount: Int = 3
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { index in
                ChatThreadSkeletonRow()
                    .padding(.vertical, 10)

                if index < rowCount - 1 {
                    Divider()
                        .background(ConnectColors.divider)
                }
            }
        }
        .redacted(reason: .placeholder)
        .opacity(isPulsing ? 0.55 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct ChatThreadSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ConnectColors.muted)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(ConnectColors.divider, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ConnectColors.muted)
                        .frame(width: 150, height: 12)

                    Spacer()

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ConnectColors.muted)
                        .frame(width: 56, height: 10)
                }

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ConnectColors.muted)
                    .frame(width: 220, height: 10)
            }
        }
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

        ChatThreadsListView(threads: threads, onSelect: { _ in }, onDelete: { _ in })
            .padding()
            .background(ConnectColors.background)
            .previewLayout(.sizeThatFits)
    }
}
