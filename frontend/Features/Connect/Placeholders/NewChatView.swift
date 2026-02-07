import SwiftUI

struct NewChatView: View {
    @State private var email = ""

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

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
