import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    enum AuthFlow: String, CaseIterable {
        case signIn = "Sign in"
        case signUp = "Sign up"

        var createsUser: Bool {
            switch self {
            case .signIn:
                return false
            case .signUp:
                return true
            }
        }
    }

    @Published var email = ""
    @Published var token = ""
    @Published var password = ""
    @Published var isAwaitingToken = false
    @Published var authFlow: AuthFlow = .signIn

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
        await sessionManager.sendOtp(email: email, createUser: authFlow.createsUser)
        if sessionManager.errorMessage == nil {
            isAwaitingToken = true
        }
    }

    func verifyOtp(using sessionManager: SessionManager) async {
        await sessionManager.verifyOtp(email: email, token: token)
    }

    func login(using sessionManager: SessionManager) async {
        await sessionManager.login(email: email, password: password)
    }
}
