import SwiftUI

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.9, blue: 0.81).opacity(0.35),
                    Color(red: 0.5, green: 0.85, blue: 0.75).opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("ImInLogov2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)

                Text("I'm In")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
                    .scaleEffect(pulse ? 1.03 : 0.99)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        .onAppear {
            pulse = true
        }
    }
}
