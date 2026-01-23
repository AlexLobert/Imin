import SwiftUI

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.68, green: 0.86, blue: 1.0), Color(red: 0.25, green: 0.45, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 220, height: 220)
                .offset(x: -90, y: -140)

            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: 180)

            Text("I'm in")
                .font(.custom("Avenir Next", size: 42))
                .fontWeight(.heavy)
                .foregroundColor(.black)
                .scaleEffect(pulse ? 1.05 : 0.98)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
        .onAppear {
            pulse = true
        }
    }
}
