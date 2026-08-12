import SwiftUI

/// A soft accent-tinted wash with slowly drifting music glyphs behind it —
/// the launch screen's backdrop, in the same spirit as ClassMate's ambient
/// background (a faint field of drifting symbols under the brand mark).
/// Honors Reduce Motion by freezing the drift.
struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let accent: Color
    let seed: Int

    init(accent: Color, seed: Int = 3) {
        self.accent = accent
        self.seed = seed
    }

    private static let glyphs = ["♪", "♫", "○", "∞", "★", "≈", "•"]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                var rng = SplitMix64(seed: UInt64(seed) &* 0x9E3779B9)
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<18 {
                    let baseX = rng.nextUnit() * size.width
                    let baseY = rng.nextUnit() * size.height
                    let drift = CGFloat(sin(t * 0.15 + Double(index))) * 14
                    let glyph = Self.glyphs[index % Self.glyphs.count]
                    let fontSize = 14 + rng.nextUnit() * 24
                    let alpha = 0.06 + rng.nextUnit() * 0.10
                    let resolved = context.resolve(
                        Text(glyph).font(.system(size: fontSize, weight: .semibold))
                    )
                    context.opacity = alpha
                    context.draw(resolved, at: CGPoint(x: baseX, y: baseY + drift), anchor: .center)
                }
            }
        }
        .foregroundStyle(accent)
        .ignoresSafeArea()
    }
}

/// Deterministic RNG so the layout is stable per seed across frames.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextUnit() -> CGFloat {
        CGFloat(next() >> 11) / CGFloat(1 << 53)
    }
}
