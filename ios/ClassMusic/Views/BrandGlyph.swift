import SwiftUI

/// The C+M glyph geometry — pulled out of `BrandLoader` so both the
/// animated loader and the static `BrandMarkView` trace the exact same
/// paths instead of keeping two copies of these numbers in sync by hand.
enum BrandGlyph {
    /// The C arc — center (237,253), radius 144, from its top-right tip
    /// sweeping counterclockwise down to the bottom.
    static func cPath(progress: Double) -> Path? {
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
    static func mPath(progress: Double) -> Path? {
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

/// The fixed (non-animated) brand mark: a rounded-square card filled with
/// `background` (normally the current theme's accent, so the mark actually
/// recolors with the theme instead of being a flat baked-in PNG) with the
/// real app icon artwork — `BrandMarkTemplate`, a template-rendered (alpha
/// masked, colorless) cutout of the same glyph used on the App Store icon —
/// laid on top in `glyphColor`. This is the actual logo, not the simplified
/// two-stroke approximation `BrandLoader` draws for its loop animation.
struct BrandMarkView: View {
    var size: CGFloat = 40
    var background: Color
    var glyphColor: Color = .white

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(background)
            .overlay {
                Image("BrandMarkTemplate")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(glyphColor)
                    .padding(size * 0.16)
            }
            .frame(width: size, height: size)
    }
}

/// The shared brand lockup shown at the top of every main screen (Search,
/// Library, Settings) — the designed logo-with-wordmark artwork itself
/// (`BrandLogoWithText`), not a hand-rebuilt mark+text approximation of it.
struct BrandHeaderBar: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        // `.template` treats the artwork as a plain alpha mask (it's
        // already a single flat color) and retints it with the theme
        // accent — the same color the launch animation's Lottie scene gets
        // recoloured to, so the two read as the same brand color.
        Image("BrandLogoWithText")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(settings.theme.accent)
            .frame(height: 44)
    }
}
