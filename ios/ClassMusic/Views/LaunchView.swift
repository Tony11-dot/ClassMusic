import SwiftUI

/// The launch animation, staged like ClassMate's splash: a themed surface,
/// a soft ambient wash of drifting glyphs fading in behind, the brand mark
/// popping in with a spring, the wordmark sliding up + fading in beside it,
/// a brief hold, then a fade to the app.
struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let theme: AppTheme
    let font: AppFont
    let onFinished: () -> Void

    @State private var decorIn = false
    @State private var markIn = false
    @State private var showWord = false
    @State private var faded = false
    @State private var finished = false

    private let markSize: CGFloat = 96

    var body: some View {
        if let scene = LaunchScene.animation(surface: theme.surface, accent: theme.accent) {
            // Two earlier attempts at sizing this (a `.scaleEffect`+`.clipped`
            // stack, then a manual `GeometryReader`-sized box) both missed
            // the actual cause: `LaunchSceneView` never told UIKit it was
            // allowed to shrink below the composition's native 1280×720,
            // so no SwiftUI frame we gave it was ever honored — it rendered
            // at intrinsic size regardless. Now that `LaunchSceneView` sets
            // compression resistance low and reports its own fitted size via
            // `sizeThatFits`, this can go back to matching ClassMate's own
            // reference sizing exactly (`Center(child: Lottie(fit: contain))`
            // full-width): plain aspect-fit at the available width, centered
            // by the ZStack's default alignment — no extra box, scale, or
            // clip layered on top.
            ZStack {
                theme.surface.ignoresSafeArea()
                AmbientBackground(accent: theme.accent)
                    .opacity(decorIn ? 1 : 0)
                    .ignoresSafeArea()
                LaunchSceneView(animation: scene, onFinished: finishOnce)
                    .aspectRatio(LaunchScene.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            .task {
                withAnimation(.easeOut(duration: 1.1)) { decorIn = true }
                // A safety net: if playback never reports completion
                // (launched into the background, animations disabled), hand
                // off anyway.
                try? await Task.sleep(for: .seconds(LaunchScene.duration + 1.2))
                finishOnce()
            }
        } else {
            nativeBody
        }
    }

    private var nativeBody: some View {
        ZStack {
            theme.surface.ignoresSafeArea()
            AmbientBackground(accent: theme.accent)
                .opacity(decorIn ? 1 : 0)

            VStack(spacing: 14) {
                BrandMarkView(size: markSize, background: theme.accent)
                    .shadow(color: theme.accent.opacity(0.35), radius: 16, y: 8)
                    .scaleEffect(markIn ? 1 : 0.35)
                    .opacity(markIn ? 1 : 0)

                if showWord {
                    Text("ClassMusic")
                        .font(font.font(size: 26, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .opacity(faded ? 0 : 1)
        }
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            decorIn = true
            markIn = true
            showWord = true
            try? await Task.sleep(for: .milliseconds(700))
            finishOnce()
            return
        }
        withAnimation(.easeOut(duration: 1.1)) { decorIn = true }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { markIn = true }
        try? await Task.sleep(for: .milliseconds(780))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { showWord = true }
        try? await Task.sleep(for: .milliseconds(760))
        withAnimation(.easeIn(duration: 0.35)) { faded = true }
        try? await Task.sleep(for: .milliseconds(360))
        finishOnce()
    }

    private func finishOnce() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}
