import SwiftUI

/// The looping loading spinner, ported directly from ClassMate's own
/// `CmLoading` (`cm_loading.dart`) — not the "N" variant ClassMate-Notes
/// forked for "ClassNotes", the original "C then M" (ClassMate's initials,
/// which ClassMusic happens to share): the C arc strokes in, then the M
/// rises stem-valley-stem, then both cross-fade into the real mark, hold,
/// and loop. Geometry (arc center/radius/angles, the M polyline points,
/// stroke widths, timeline fractions) is copied verbatim from the Flutter
/// source's 512-unit trace — this is the same animation, not a reproduction.
struct BrandLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let size: CGFloat
    var tint: Color

    init(size: CGFloat = 56, tint: Color) {
        self.size = size
        self.tint = tint
    }

    private static let period: Double = 2.0

    var body: some View {
        if reduceMotion {
            brandMark.opacity(1)
        } else {
            TimelineView(.animation) { timeline in
                let phase = (timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: Self.period)) / Self.period
                let cProgress = ease(seg(phase, 0.00, 0.36))
                let mProgress = ease(seg(phase, 0.32, 0.64))
                let crossfade = seg(phase, 0.66, 0.78)
                let restartFade = seg(phase, 0.90, 1.00)
                let strokesOpacity = (1 - crossfade) * (1 - restartFade)
                let iconOpacity = crossfade * (1 - restartFade)

                ZStack {
                    Canvas { context, canvasSize in
                        let scale = min(canvasSize.width, canvasSize.height) / 512
                        let transform = CGAffineTransform(scaleX: scale, y: scale)
                        if cProgress > 0, let cPath = Self.cPath(progress: cProgress)?.applying(transform) {
                            context.stroke(cPath, with: .color(tint), style: StrokeStyle(lineWidth: 44 * scale, lineCap: .butt))
                        }
                        if mProgress > 0, let mPath = Self.mPath(progress: mProgress)?.applying(transform) {
                            context.stroke(
                                mPath, with: .color(tint),
                                style: StrokeStyle(lineWidth: 42 * scale, lineCap: .butt, lineJoin: .miter, miterLimit: 8)
                            )
                        }
                    }
                    .opacity(strokesOpacity)

                    brandMark.opacity(iconOpacity)
                }
            }
            .frame(width: size, height: size)
            .accessibilityLabel("Loading")
        }
    }

    private var brandMark: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private func seg(_ v: Double, _ from: Double, _ to: Double) -> Double {
        min(max((v - from) / (to - from), 0), 1)
    }

    private func ease(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// The C arc — center (237,253), radius 144, from its top-right tip
    /// sweeping counterclockwise down to the bottom.
    private static func cPath(progress: Double) -> Path? {
        var path = Path()
        let center = CGPoint(x: 237, y: 253)
        let radius: CGFloat = 144
        let startDeg = -43.0
        let sweepDeg = -243.0
        path.addArc(
            center: center, radius: radius,
            startAngle: .degrees(startDeg), endAngle: .degrees(startDeg + sweepDeg * progress),
            clockwise: sweepDeg < 0
        )
        return path
    }

    /// The M: bottom-left stem up, diagonal into the valley, up to the peak,
    /// down the right stem — traced up to `progress` of its total length.
    private static func mPath(progress: Double) -> Path? {
        let points = [
            CGPoint(x: 203, y: 340),
            CGPoint(x: 203, y: 199),
            CGPoint(x: 297, y: 304),
            CGPoint(x: 400, y: 188),
            CGPoint(x: 400, y: 418),
        ]
        var lengths: [CGFloat] = []
        var total: CGFloat = 0
        for index in 1..<points.count {
            let segment = hypot(points[index].x - points[index - 1].x, points[index].y - points[index - 1].y)
            lengths.append(segment)
            total += segment
        }
        let target = total * progress
        var path = Path()
        path.move(to: points[0])
        var covered: CGFloat = 0
        for index in 1..<points.count {
            let segment = lengths[index - 1]
            if covered + segment <= target {
                path.addLine(to: points[index])
                covered += segment
            } else {
                let remaining = target - covered
                let fraction = segment > 0 ? remaining / segment : 0
                let interpolated = CGPoint(
                    x: points[index - 1].x + (points[index].x - points[index - 1].x) * fraction,
                    y: points[index - 1].y + (points[index].y - points[index - 1].y) * fraction
                )
                path.addLine(to: interpolated)
                break
            }
        }
        return path
    }
}
