import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var onFinished: (() -> Void)?

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.backgroundBehavior = .pauseAndRestore
        view.contentMode = .scaleAspectFit
        view.loopMode = .playOnce
        view.animation = LottieAnimation.named(name)
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        guard uiView.isAnimationPlaying == false else { return }
        uiView.play { finished in
            if finished {
                DispatchQueue.main.async {
                    onFinished?()
                }
            }
        }
    }
}
