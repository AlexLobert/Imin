import SwiftUI

struct MeView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Me")
                    .font(.custom("Avenir Next", size: 26))
                    .fontWeight(.heavy)

                if let session = sessionManager.session {
                    Text("Signed in as")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundColor(.black.opacity(0.6))

                    Text(session.userId)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundColor(.black)
                }

                Text("Stay in control of who sees you and when your status resets.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(.black.opacity(0.7))

                Button(action: {
                    Task {
                        await sessionManager.signOut()
                    }
                }) {
                    Text("Sign out")
                        .font(.custom("Avenir Next", size: 16))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .disabled(sessionManager.isLoading)

                Spacer()
            }
            .padding(24)
        }
    }
}
