import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Let's sync up")
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.heavy)
                        .foregroundColor(.black)

                    Text("Sign in to see who's down right now.")
                        .font(.custom("Avenir Next", size: 16))
                        .foregroundColor(.black.opacity(0.75))
                }

                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    Button("Send code") {
                        Task {
                            await viewModel.sendOtp(using: sessionManager)
                        }
                    }
                    .disabled(!viewModel.canSendCode || sessionManager.isLoading)
                    .buttonStyle(PrimaryButtonStyle())

                    if viewModel.isAwaitingToken {
                        TextField("Code", text: $viewModel.token)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)

                        Button("Verify") {
                            Task {
                                await viewModel.verifyOtp(using: sessionManager)
                            }
                        }
                        .disabled(!viewModel.canVerify || sessionManager.isLoading)
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(20)
                .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                .cornerRadius(24)

                if sessionManager.isLoading {
                    ProgressView()
                        .tint(.black)
                }

                if let errorMessage = sessionManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.black)
                        .font(.custom("Avenir Next", size: 14))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(24)
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 16))
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.55, green: 0.6, blue: 0.7).opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(14)
    }
}
