import Observation
import SwiftUI

/// A hex-defined color, the same representation ClassMate's theme tokens use.
struct HexColor {
    let color: Color
    let red: Double
    let green: Double
    let blue: Double

    init(_ hex: String) {
        var value = UInt64()
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        red = Double((value & 0xFF0000) >> 16) / 255
        green = Double((value & 0x00FF00) >> 8) / 255
        blue = Double(value & 0x0000FF) / 255
        color = Color(red: red, green: green, blue: blue)
    }
}

/// The 19 built-in themes, ported directly from ClassMate/ClassMate-Notes
/// (`ThemePreset` in the ClassMateTheme package) so both apps offer the same
/// palette, named the same way, chosen the same way — plus "System default",
/// which ClassMate also offers alongside its presets.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    // Light family
    case light, coffee, matcha, rose, sand, sky, lavender, peach, mint
    // Dark family
    case dark, midnight, nord, forest, dracula, obsidian, wine, solarized, plum, ocean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System default"
        case .rose: "Rosé"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    static var lightFamily: [AppTheme] { [.light, .coffee, .matcha, .rose, .sand, .sky, .lavender, .peach, .mint] }
    static var darkFamily: [AppTheme] { [.dark, .midnight, .nord, .forest, .dracula, .obsidian, .wine, .solarized, .plum, .ocean] }

    var isDark: Bool { Self.darkFamily.contains(self) }

    /// nil means "follow the system appearance" — only `.system` does this.
    var colorScheme: ColorScheme? {
        self == .system ? nil : (isDark ? .dark : .light)
    }

    private struct Tokens {
        let accent, surface, surfaceRaised, paper, ink, inkSecondary, separator: String
    }

    private static let tokens: [AppTheme: Tokens] = [
        .light: Tokens(accent: "#256489", surface: "#F6F9FE", surfaceRaised: "#E5E8ED", paper: "#FFFFFF", ink: "#181C20", inkSecondary: "#41474D", separator: "#C1C7CE"),
        .coffee: Tokens(accent: "#88511E", surface: "#F3E9D8", surfaceRaised: "#E9DCC7", paper: "#FBF4E7", ink: "#3B2F25", inkSecondary: "#6A5B4B", separator: "#CDBBA0"),
        .matcha: Tokens(accent: "#416835", surface: "#F1F4E7", surfaceRaised: "#DFE5CC", paper: "#F8FAEF", ink: "#2B3327", inkSecondary: "#586353", separator: "#C4CCAF"),
        .rose: Tokens(accent: "#8D4A5D", surface: "#FAF4ED", surfaceRaised: "#EADFD4", paper: "#FFFAF3", ink: "#575279", inkSecondary: "#797593", separator: "#DDD0C4"),
        .sand: Tokens(accent: "#8C4F26", surface: "#F5EDE0", surfaceRaised: "#E4D7C2", paper: "#FCF6EC", ink: "#3E342A", inkSecondary: "#6E6152", separator: "#D2C2AB"),
        .sky: Tokens(accent: "#38608F", surface: "#EDF3F9", surfaceRaised: "#D6E2ED", paper: "#F6FAFD", ink: "#27333E", inkSecondary: "#556472", separator: "#C0CEDC"),
        .lavender: Tokens(accent: "#66558E", surface: "#F3EFFA", surfaceRaised: "#DFD8ED", paper: "#FAF7FE", ink: "#332C43", inkSecondary: "#635A73", separator: "#CEC4DE"),
        .peach: Tokens(accent: "#904B3F", surface: "#FBEEE7", surfaceRaised: "#EBD8CD", paper: "#FFF7F2", ink: "#43322C", inkSecondary: "#77605A", separator: "#DCC7BD"),
        .mint: Tokens(accent: "#096B5A", surface: "#EAF4EF", surfaceRaised: "#D1E1DA", paper: "#F4FAF7", ink: "#26332E", inkSecondary: "#54655E", separator: "#BFD3CB"),
        .dark: Tokens(accent: "#94CDF7", surface: "#101417", surfaceRaised: "#262A2E", paper: "#0A0F12", ink: "#DFE3E8", inkSecondary: "#C1C7CE", separator: "#41474D"),
        .midnight: Tokens(accent: "#8FA6FF", surface: "#0E1428", surfaceRaised: "#212A48", paper: "#0A0F20", ink: "#DCE2F4", inkSecondary: "#9AA6C6", separator: "#2E3A5C"),
        .nord: Tokens(accent: "#88C0D0", surface: "#2E3440", surfaceRaised: "#434C5E", paper: "#272C36", ink: "#ECEFF4", inkSecondary: "#C8CFDC", separator: "#434C5E"),
        .forest: Tokens(accent: "#A7C080", surface: "#2D353B", surfaceRaised: "#3D484D", paper: "#272E33", ink: "#D3C6AA", inkSecondary: "#A6B0A0", separator: "#3D484D"),
        .dracula: Tokens(accent: "#BD93F9", surface: "#282A36", surfaceRaised: "#3C3F51", paper: "#21222C", ink: "#F8F8F2", inkSecondary: "#B8BAC8", separator: "#44475A"),
        .obsidian: Tokens(accent: "#57D6E0", surface: "#111315", surfaceRaised: "#23272B", paper: "#0B0C0E", ink: "#E4E6E8", inkSecondary: "#9BA1A6", separator: "#2A2F34"),
        .wine: Tokens(accent: "#EC9AAE", surface: "#241016", surfaceRaised: "#3D1F28", paper: "#1C0B10", ink: "#F3DDE3", inkSecondary: "#C79AA4", separator: "#4A2C33"),
        .solarized: Tokens(accent: "#C99A2E", surface: "#002B36", surfaceRaised: "#0E4653", paper: "#00232C", ink: "#93A1A1", inkSecondary: "#839496", separator: "#0E4653"),
        .plum: Tokens(accent: "#C9A2ED", surface: "#1E1526", surfaceRaised: "#342740", paper: "#17101E", ink: "#E9DFF3", inkSecondary: "#B1A3C0", separator: "#362A43"),
        .ocean: Tokens(accent: "#56C7D4", surface: "#0C1E24", surfaceRaised: "#1D3A43", paper: "#07171C", ink: "#DBEBEE", inkSecondary: "#98B0B6", separator: "#23424B"),
    ]

    /// `.system` follows the OS appearance, so it has no fixed palette — it
    /// resolves to `light`'s tokens for previews and falls back to dynamic
    /// system colors (`.systemBackground` etc.) wherever it's actually drawn.
    private var resolvedTokens: Tokens { Self.tokens[self] ?? Self.tokens[.light]! }

    var accent: Color { HexColor(resolvedTokens.accent).color }
    var surface: Color { self == .system ? Color(.systemBackground) : HexColor(resolvedTokens.surface).color }
    var surfaceRaised: Color { self == .system ? Color(.secondarySystemBackground) : HexColor(resolvedTokens.surfaceRaised).color }
    var paper: Color { HexColor(resolvedTokens.paper).color }
    var ink: Color { self == .system ? Color(.label) : HexColor(resolvedTokens.ink).color }
    var inkSecondary: Color { self == .system ? Color(.secondaryLabel) : HexColor(resolvedTokens.inkSecondary).color }
    var separator: Color { self == .system ? Color(.separator) : HexColor(resolvedTokens.separator).color }
}

/// The curated font pack, ported directly from ClassMate-Notes's
/// `FontLibrary` — same ids, same names, same order, same iOS-bundled faces
/// (no bundling/licensing needed). The brand face (Cabinet Grotesk) is
/// The brand face (Cabinet Grotesk) is included too — same three bundled
/// .ttf files as ClassMate-Notes — and is the default, same as there.
enum AppFont: String, CaseIterable, Identifiable {
    case cabinet, system
    case noteworthy, bradley, marker, chalkboard, snell, savoye
    case rounded, newyork, georgia, menlo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cabinet: "Cabinet Grotesk"
        case .system: "Default"
        case .noteworthy: "Noteworthy"
        case .bradley: "Bradley Hand"
        case .marker: "Marker Felt"
        case .chalkboard: "Chalkboard"
        case .snell: "Snell Roundhand"
        case .savoye: "Savoye"
        case .rounded: "Rounded"
        case .newyork: "New York"
        case .georgia: "Georgia"
        case .menlo: "Menlo"
        }
    }

    private var postScriptName: String? {
        switch self {
        case .cabinet, .system: nil
        case .noteworthy: "Noteworthy-Light"
        case .bradley: "BradleyHandITCTT-Bold"
        case .marker: "MarkerFelt-Thin"
        case .chalkboard: "ChalkboardSE-Regular"
        case .snell: "SnellRoundhand"
        case .savoye: "SavoyeLetPlain"
        // SF Rounded and New York are only reachable through a system font
        // descriptor + design, never by PostScript name (Font.custom would
        // silently fall back to the system face) — handled in font(size:).
        case .rounded, .newyork, .georgia, .menlo: nil
        }
    }

    /// Weight is honored where the underlying face actually has distinct
    /// weight variants (Cabinet, system, rounded, New York, Menlo, Georgia);
    /// the decorative script/handwriting faces only ship one weight, so it's
    /// silently ignored there — same as it would be if you asked the system
    /// for a bold Snell Roundhand.
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .cabinet: return CMFonts.font(size: size, weight: weight)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .newyork: return .system(size: size, weight: weight, design: .serif)
        case .georgia: return .custom(weight == .bold || weight == .heavy || weight == .black ? "Georgia-Bold" : "Georgia", size: size)
        case .menlo: return .custom(weight == .bold || weight == .heavy || weight == .black ? "Menlo-Bold" : "Menlo-Regular", size: size)
        case .system: return .system(size: size, weight: weight)
        default:
            guard let postScriptName else { return .system(size: size, weight: weight) }
            return .custom(postScriptName, size: size)
        }
    }

    /// A UIKit equivalent of `font(size:weight:)`, for the handful of
    /// surfaces SwiftUI's `.font` environment never reaches — the tab bar
    /// in particular, which renders its item labels through `UITabBarItem`
    /// and ignores SwiftUI font modifiers/environment entirely.
    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch self {
        case .cabinet:
            CMFonts.registerIfNeeded()
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "CabinetGrotesk-Bold"
            case .medium, .semibold: name = "CabinetGrotesk-Medium"
            default: name = "CabinetGrotesk-Regular"
            }
            return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        case .rounded:
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .newyork:
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .georgia:
            let name = (weight == .bold || weight == .heavy || weight == .black) ? "Georgia-Bold" : "Georgia"
            return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        case .menlo:
            let name = (weight == .bold || weight == .heavy || weight == .black) ? "Menlo-Bold" : "Menlo-Regular"
            return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        case .system:
            return .systemFont(ofSize: size, weight: weight)
        default:
            guard let postScriptName else { return .systemFont(ofSize: size, weight: weight) }
            return UIFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
    }
}

/// App-wide appearance preferences — theme and font — applied at the root of
/// the view tree (see ClassMusicApp/ContentView) and persisted across
/// launches.
@Observable
@MainActor
final class AppSettings {
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    var font: AppFont {
        didSet { UserDefaults.standard.set(font.rawValue, forKey: Keys.font) }
    }

    private enum Keys {
        static let theme = "settings.theme"
        static let font = "settings.font"
    }

    init(defaults: UserDefaults = .standard) {
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        font = AppFont(rawValue: defaults.string(forKey: Keys.font) ?? "") ?? .cabinet
    }
}
