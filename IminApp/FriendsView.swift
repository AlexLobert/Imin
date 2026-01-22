import SwiftUI

struct FriendsView: View {
    @State private var searchText = ""

    private let friends = [
        FriendRow(name: "Ava", handle: "@ava", status: "In"),
        FriendRow(name: "Jordan", handle: "@jordan", status: "Out"),
        FriendRow(name: "Maya", handle: "@maya", status: "In")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Find your people")
                            .font(.custom("Avenir Next", size: 24))
                            .fontWeight(.heavy)

                        TextField("Search name, handle, email, or phone", text: $searchText)
                            .textFieldStyle(.roundedBorder)

                        actionRow

                        friendSection(title: "Friends on I'm in", friends: friends)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan contacts")
                        .font(.custom("Avenir Next", size: 15))
                        .fontWeight(.bold)
                    Text("Find who's already here.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundColor(.black.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                .cornerRadius(16)
            }

            Button(action: {}) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Invite friends")
                        .font(.custom("Avenir Next", size: 15))
                        .fontWeight(.bold)
                    Text("Share your link.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundColor(.black.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
    }

    private func friendSection(title: String, friends: [FriendRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.bold)

            ForEach(friends) { friend in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.custom("Avenir Next", size: 15))
                            .fontWeight(.bold)
                        Text(friend.handle)
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    Spacer()
                    Text(friend.status)
                        .font(.custom("Avenir Next", size: 12))
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                .background(friend.status == "In" ? Color(red: 0.55, green: 0.6, blue: 0.7) : Color(red: 0.98, green: 0.95, blue: 0.85))
                .foregroundColor(friend.status == "In" ? .white : .black)
                .cornerRadius(10)
        }
        .padding(12)
        .background(Color(red: 0.98, green: 0.95, blue: 0.85))
        .cornerRadius(16)
    }
        }
    }
}

private struct FriendRow: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let status: String
}
