import Lottie
import SwiftUI

/// Plays a `LottieAnimation` once and calls `onFinished`.
struct LaunchSceneView: UIViewRepresentable {
    let animation: LottieAnimation
    let onFinished: () -> Void

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(animation: animation)
        view.contentMode = .scaleAspectFit
        view.backgroundBehavior = .pauseAndRestore
        view.loopMode = .playOnce
        view.backgroundColor = .clear
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.play { _ in
            // Fires with `false` when playback was interrupted (backgrounded
            // mid-launch). Either way the app has to move on — never strand
            // the user on a splash screen.
            onFinished()
        }
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}
