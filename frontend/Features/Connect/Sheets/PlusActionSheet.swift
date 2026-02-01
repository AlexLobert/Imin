import SwiftUI

struct PlusActionSheet: ViewModifier {
    @Binding var isPresented: Bool
    let onNewChat: () -> Void
    let onNewCircle: () -> Void
    let onAddFriend: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Create", isPresented: $isPresented, titleVisibility: .visible) {
                Button("New Chat") {
                    onNewChat()
                }
                Button("New Circle") {
                    onNewCircle()
                }
                Button("Add Friend") {
                    onAddFriend()
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

extension View {
    func plusActionSheet(
        isPresented: Binding<Bool>,
        onNewChat: @escaping () -> Void,
        onNewCircle: @escaping () -> Void,
        onAddFriend: @escaping () -> Void
    ) -> some View {
        modifier(PlusActionSheet(
            isPresented: isPresented,
            onNewChat: onNewChat,
            onNewCircle: onNewCircle,
            onAddFriend: onAddFriend
        ))
    }
}
