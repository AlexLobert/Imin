import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var token = ""
    @Published var isAwaitingToken = false

    var canSendCode: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canVerify: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sendOtp(using sessionManager: SessionManager) async {
        await sessionManager.sendOtp(email: email)
        if sessionManager.errorMessage == nil {
            isAwaitingToken = true
        }
    }

    func verifyOtp(using sessionManager: SessionManager) async {
        await sessionManager.verifyOtp(email: email, token: token)
    }
}
