import CoreText
import SwiftUI

/// Registers ClassMate's own bundled Cabinet Grotesk faces, ported directly
/// (same three .ttf files) so ClassMusic's default type matches ClassMate's.
enum CMFonts {
    static let family = "Cabinet Grotesk"

    /// Runs exactly once, on whichever thread asks first — a `static let` is
    /// lazily initialized under the runtime's own lock.
    private static let registration: Void = {
        let faces = ["CabinetGrotesk-Regular", "CabinetGrotesk-Medium", "CabinetGrotesk-Bold"]
        for face in faces {
            guard let url = Bundle.main.url(forResource: face, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func registerIfNeeded() {
        _ = registration
    }

    /// Falls back to the system font if registration didn't take —
    /// `Font.custom` with an unregistered name silently renders in the
    /// system face, so a missing resource degrades instead of breaking.
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerIfNeeded()
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "CabinetGrotesk-Bold"
        case .medium, .semibold: name = "CabinetGrotesk-Medium"
        default: name = "CabinetGrotesk-Regular"
        }
        return .custom(name, size: size)
    }
}
