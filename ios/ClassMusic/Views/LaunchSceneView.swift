import Lottie
import SwiftUI

/// Plays a `LottieAnimation` once and calls `onFinished`.
///
/// It reports its own size (`sizeThatFits`) rather than leaving SwiftUI to
/// infer one from Auto Layout: a `LottieAnimationView`'s intrinsic size is
/// the composition's own (this scene is authored 1280×720), and a
/// representable that never answers the proposal is laid out at that size
/// no matter what frame SwiftUI offered it.
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
        // The composition is authored at 1280×720, and that is the view's
        // intrinsic size. At the DEFAULT compression resistance UIKit
        // refuses to lay it out any narrower than 1280 points — the actual
        // cause of the scene rendering oversized/off-screen regardless of
        // whatever SwiftUI frame it was given.
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.play { _ in
            // Fires with `false` when playback was interrupted (backgrounded
            // mid-launch). Either way the app has to move on — never strand
            // the user on a splash screen.
            onFinished()
        }
        return view
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize, uiView: LottieAnimationView, context: Context
    ) -> CGSize? {
        LaunchScene.fitted(
            aspectRatio: LaunchScene.aspectRatio,
            into: CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
        )
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}
