import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var onFinished: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.backgroundBehavior = .pauseAndRestore
        view.contentMode = .scaleAspectFit
        view.loopMode = .playOnce
        view.animation = LottieAnimation.named(name)
        if view.animation == nil {
            finishIfNeeded(context: context)
        }
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.animation == nil {
            finishIfNeeded(context: context)
            return
        }
        guard uiView.isAnimationPlaying == false else { return }
        uiView.play { finished in
            if finished {
                DispatchQueue.main.async {
                    finishIfNeeded(context: context)
                }
            }
        }
    }

    private func finishIfNeeded(context: Context) {
        guard context.coordinator.hasFinished == false else { return }
        context.coordinator.hasFinished = true
        DispatchQueue.main.async {
            onFinished?()
        }
    }

    class Coordinator {
        var hasFinished = false
    }
}
