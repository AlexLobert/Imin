import SwiftUI

struct AddFriendView: View {
    @State private var handle = ""

    var body: some View {
        Form {
            Section(header: Text("Invite friend")) {
                TextField("Handle or email", text: $handle)
            }
            Button("Send invite") {}
        }
        .navigationTitle("Add Friend")
    }
}
