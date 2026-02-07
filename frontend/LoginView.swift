import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.9, blue: 0.81).opacity(0.25),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Let's sync up")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)

                    Text("Enter your email and we'll send a one-time code.")
                        .font(.system(size: 15))
                        .foregroundColor(DesignColors.textSecondary)
                }

                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if AppEnvironment.backend == .supabase {
                        Button("Send code") {
                            Task {
                                await viewModel.sendOtp(using: sessionManager)
                            }
                        }
                        .disabled(!viewModel.canSendCode || sessionManager.isLoading)
                        .buttonStyle(AppPillButtonStyle(kind: .mint))

                        if viewModel.isAwaitingToken {
                            TextField("Code", text: $viewModel.token)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.numberPad)
                                .padding(14)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Button("Verify") {
                                Task {
                                    await viewModel.verifyOtp(using: sessionManager)
                                }
                            }
                            .disabled(!viewModel.canVerify || sessionManager.isLoading)
                            .buttonStyle(AppPillButtonStyle(kind: .mint))
                        }
                    } else {
                        SecureField("Password", text: $viewModel.password)
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button("Sign in") {
                            Task {
                                await viewModel.login(using: sessionManager)
                            }
                        }
                        .disabled(!viewModel.canLogin || sessionManager.isLoading)
                        .buttonStyle(AppPillButtonStyle(kind: .mint))
                    }
                }
                .padding(20)
                .appCard()

                if sessionManager.isLoading {
                    ProgressView()
                        .tint(DesignColors.textPrimary)
                }

                if let errorMessage = sessionManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(DesignColors.textSecondary)
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(24)
        }
    }
}
