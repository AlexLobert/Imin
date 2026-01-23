import SwiftUI

struct LaunchOverlayView: View {
    @Binding var isPresented: Bool
    let onAnimationFinished: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppColors.accentGreen.opacity(0.18),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("IminLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .opacity(0.35)

                LottieView(name: "im_in_launch_animation") {
                    onAnimationFinished()
                }
                .frame(width: 220, height: 220)
            }
        }

    }
}
