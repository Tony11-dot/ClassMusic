import SwiftUI
import UIKit

#if canImport(Lottie)
import Lottie
#endif

/// The designed launch animation — the Lottie scene exported from Jitter —
/// played once, then handed off. Ported from ClassMate-Notes's identical
/// `LaunchScene` (same recolouring approach, same two-pass strategy): the
/// baked white canvas becomes the current theme's `surface` and the baked
/// brand blue becomes the theme's `accent`, so the whole scene tracks
/// whichever theme the user picked instead of always showing the color it
/// was designed in. The CM mark is an embedded PNG inside the composition
/// (vector recolouring can't reach raster pixels), so it's retinted
/// separately with its alpha preserved.
enum LaunchScene {
    /// The two colours baked into the exported artwork (sampled directly
    /// from `LaunchScene.json`), matched within tolerance and swapped for
    /// the live theme.
    static let canvas: [Double] = [1, 1, 1]
    static let mark: [Double] = [0.059, 0.169, 0.714]

    static var rawJSON: Data? {
        guard let url = Bundle.main.url(forResource: "LaunchScene", withExtension: "json")
        else { return nil }
        return try? Data(contentsOf: url)
    }

    static var isAvailable: Bool { rawJSON != nil }

    /// The composition's own proportions, so the scene lays out at the
    /// shape it was authored in rather than a hardcoded guess.
    static var aspectRatio: CGFloat {
        guard let json = rawJSON,
              let doc = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let width = doc["w"] as? Double, let height = doc["h"] as? Double,
              width > 0, height > 0
        else { return 16.0 / 9.0 }
        return CGFloat(width / height)
    }

    /// How long the scene runs — used to schedule the hand-off even if the
    /// completion callback is missed (a backgrounded launch drops it).
    static var duration: TimeInterval {
        guard let json = rawJSON,
              let doc = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let frames = doc["op"] as? Double, let rate = doc["fr"] as? Double, rate > 0
        else { return 2.6 }
        return frames / rate
    }

    #if canImport(Lottie)
    /// The scene recoloured for a theme. Cached, because rebuilding it means
    /// re-encoding an embedded bitmap and the launch is the one place that
    /// can't afford to be slow.
    @MainActor private static var cache: [String: LottieAnimation] = [:]

    @MainActor
    static func animation(surface: Color, accent: Color) -> LottieAnimation? {
        let key = "\(surface.hexKey)-\(accent.hexKey)"
        if let cached = cache[key] { return cached }
        guard let json = rawJSON,
              var doc = try? JSONSerialization.jsonObject(with: json) as? [String: Any]
        else { return nil }

        recolour(&doc, from: canvas, to: surface)
        recolour(&doc, from: mark, to: accent)
        tintEmbeddedImages(&doc, to: accent)

        guard let data = try? JSONSerialization.data(withJSONObject: doc),
              let animation = try? LottieAnimation.from(data: data) else {
            // A recolouring hiccup should cost the theme, never the launch.
            return rawJSON.flatMap { try? LottieAnimation.from(data: $0) }
        }
        cache[key] = animation
        return animation
    }
    #endif

    // MARK: - Recolouring

    /// Rewrites every solid fill/stroke whose colour matches `from` (within a
    /// tolerance, because exported colours are rarely exact) to `to`.
    static func recolour(_ node: inout [String: Any], from: [Double], to: Color) {
        let replacement = to.rgbComponents

        func matches(_ components: [Any]) -> Bool {
            guard components.count >= 3 else { return false }
            for index in 0..<3 {
                guard let value = components[index] as? Double,
                      abs(value - from[index]) <= 0.03 else { return false }
            }
            return true
        }

        func walk(_ value: Any) -> Any {
            if var map = value as? [String: Any] {
                let type = map["ty"] as? String
                if type == "fl" || type == "st",
                   var colour = map["c"] as? [String: Any],
                   let components = colour["k"] as? [Any], matches(components) {
                    var newValue: [Any] = [replacement.red, replacement.green, replacement.blue]
                    if components.count > 3 { newValue.append(components[3]) }
                    colour["k"] = newValue
                    map["c"] = colour
                }
                for (key, child) in map where key != "c" {
                    map[key] = walk(child)
                }
                return map
            }
            if let list = value as? [Any] { return list.map(walk) }
            return value
        }

        node = (walk(node) as? [String: Any]) ?? node
    }

    /// Retints every base64-embedded raster asset to `to`, keeping its
    /// alpha — the CM mark's shape survives, only its colour changes.
    /// Best-effort per image: a decode failure leaves that asset exactly as
    /// shipped.
    static func tintEmbeddedImages(_ doc: inout [String: Any], to: Color) {
        guard var assets = doc["assets"] as? [Any] else { return }
        for index in assets.indices {
            guard var asset = assets[index] as? [String: Any],
                  let payload = asset["p"] as? String,
                  payload.hasPrefix("data:image"),
                  let comma = payload.firstIndex(of: ","),
                  let data = Data(base64Encoded: String(payload[payload.index(after: comma)...])),
                  let image = UIImage(data: data),
                  let tinted = tint(image, with: to)?.pngData()
            else { continue }
            asset["p"] = "data:image/png;base64,\(tinted.base64EncodedString())"
            assets[index] = asset
        }
        doc["assets"] = assets
    }

    private static func tint(_ image: UIImage, with color: Color) -> UIImage? {
        let components = color.rgbComponents
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: image.size)
            // `.destinationIn` after filling keeps the source alpha and
            // replaces the colour — the same result as Flutter's srcIn.
            UIColor(red: components.red, green: components.green, blue: components.blue, alpha: 1).setFill()
            context.fill(rect)
            image.draw(in: rect, blendMode: .destinationIn, alpha: 1)
        }
    }
}

extension Color {
    /// Resolves against the current trait collection so this works for both
    /// fixed (`HexColor`) and dynamic/system colors alike.
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    /// A stable cache key for a resolved color — good enough for
    /// distinguishing themes, not meant as a real color identity.
    var hexKey: String {
        let c = rgbComponents
        return String(format: "%02X%02X%02X", Int(c.red * 255), Int(c.green * 255), Int(c.blue * 255))
    }
}
