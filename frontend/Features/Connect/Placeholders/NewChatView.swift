import SwiftUI

struct NewChatView: View {
    @State private var email = ""

    var body: some View {
        Form {
            Section(header: Text("Start a chat")) {
                TextField("Email", text: $email)
            }
            Button("Create") {}
        }
        .navigationTitle("New Chat")
    }
}
