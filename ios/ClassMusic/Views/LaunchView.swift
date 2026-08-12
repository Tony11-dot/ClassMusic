import SwiftUI

/// The launch animation, staged like ClassMate's splash: a themed surface,
/// a soft ambient wash of drifting glyphs fading in behind, the brand mark
/// popping in with a spring, the wordmark sliding up + fading in beside it,
/// a brief hold, then a fade to the app.
struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let theme: AppTheme
    let onFinished: () -> Void

    @State private var decorIn = false
    @State private var markIn = false
    @State private var showWord = false
    @State private var faded = false
    @State private var finished = false

    private let markSize: CGFloat = 96

    var body: some View {
        ZStack {
            theme.surface.ignoresSafeArea()
            AmbientBackground(accent: theme.accent)
                .opacity(decorIn ? 1 : 0)

            VStack(spacing: 14) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: markSize, height: markSize)
                    .clipShape(RoundedRectangle(cornerRadius: markSize * 0.22, style: .continuous))
                    .shadow(color: theme.accent.opacity(0.35), radius: 16, y: 8)
                    .scaleEffect(markIn ? 1 : 0.35)
                    .opacity(markIn ? 1 : 0)

                if showWord {
                    Text("ClassMusic")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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
