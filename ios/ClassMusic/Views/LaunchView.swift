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
            // Previously sized the scene with `.frame(width:)` +
            // `.aspectRatio(.fit)` and then *also* applied `.scaleEffect` +
            // `.clipped()` on top, meaning to shrink the rendered content
            // further inside the same (unscaled) layout box. That extra
            // layer fought with `LaunchSceneView`'s own UIKit
            // `contentMode = .scaleAspectFit` and clipped the wordmark
            // instead of just shrinking it. The fix: compute the exact
            // target box size directly (a fixed fraction of the shorter
            // screen dimension, height derived from the composition's real
            // aspect ratio) and hand that straight to `LaunchSceneView` with
            // nothing else layered on — `scaleAspectFit` mathematically
            // cannot crop content, it only letterboxes within whatever
            // bounds it's given, so no `.clipped()` is needed. `.position`
            // (not ZStack's default alignment, which centers within the
            // safe-area layout guide and can drift next to the
            // ignoresSafeArea background) keeps it dead-center.
            GeometryReader { geo in
                let boxWidth = min(geo.size.width, geo.size.height) * 0.46
                let boxHeight = boxWidth / LaunchScene.aspectRatio
                ZStack {
                    theme.surface.ignoresSafeArea()
                    AmbientBackground(accent: theme.accent)
                        .opacity(decorIn ? 1 : 0)
                    LaunchSceneView(animation: scene, onFinished: finishOnce)
                        .frame(width: boxWidth, height: boxHeight)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            .ignoresSafeArea()
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
