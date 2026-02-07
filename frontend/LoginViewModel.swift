import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var token = ""
    @Published var password = ""
    @Published var isAwaitingToken = false

    var canSendCode: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canVerify: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sendOtp(using sessionManager: SessionManager) async {
        await sessionManager.sendOtp(email: normalizedEmail, createUser: true)
        if sessionManager.errorMessage == nil {
            isAwaitingToken = true
        }
    }

    func verifyOtp(using sessionManager: SessionManager) async {
        await sessionManager.verifyOtp(
            email: normalizedEmail,
            token: token.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func login(using sessionManager: SessionManager) async {
        await sessionManager.login(
            email: normalizedEmail,
            password: password.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
