import SwiftUI

struct AddFriendView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var handle = ""
    @State private var bannerMessage: String?
    @State private var bannerIsError = false
    @State private var isSending = false
    private let friendRequestService = FriendRequestService()

    var body: some View {
        Form {
            Section(header: Text("Invite friend")) {
                TextField("Handle or email", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Button(isSending ? "Sending..." : "Send invite") {
                Task {
                    await sendInvite()
                }
            }
            .disabled(isSending || handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Add Friend")
        .safeAreaInset(edge: .top) {
            if let message = bannerMessage {
                bannerView(message: message, isError: bannerIsError)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: handle) { _, _ in
            if bannerMessage != nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    bannerMessage = nil
                }
            }
        }
    }

    private func bannerView(message: String, isError: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "paperplane.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(isError ? .white : DesignColors.textPrimary)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Group {
                if isError {
                    Color.red.opacity(0.9)
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.66, green: 0.9, blue: 0.81),
                            Color(red: 0.5, green: 0.85, blue: 0.75)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private func showBanner(message: String, isError: Bool) {
        withAnimation(.easeOut(duration: 0.25)) {
            bannerMessage = message
            bannerIsError = isError
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                bannerMessage = nil
            }
        }
    }

    @MainActor
    private func sendInvite() async {
        guard AppEnvironment.backend == .supabase else {
            showBanner(message: "Friend requests aren't available.", isError: true)
            return
        }
        guard let session = await sessionManager.validSession() else { return }
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await friendRequestService.sendRequest(to: trimmed, session: session)
            handle = ""
            showBanner(message: "Invite sent!", isError: false)
        } catch {
            showBanner(message: error.localizedDescription, isError: true)
        }
    }
}
