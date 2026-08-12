import SwiftUI

/// The theme + font pickers, ported to match ClassMate's own Settings
/// screen: the same 19 named themes (System default, then the light family,
/// then the dark family, each a swatch row with a checkmark), and the same
/// curated font pack, picked the same way.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            List {
                aboutSection
                presetSection(title: "Light themes", presets: [.system] + AppTheme.lightFamily)
                presetSection(title: "Dark themes", presets: AppTheme.darkFamily)
                fontSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack(spacing: 14) {
                BrandLoader(size: 52, tint: settings.theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClassMusic")
                        .font(.headline)
                    Text("Version \(Bundle.main.appVersionString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Theme

    private func presetSection(title: String, presets: [AppTheme]) -> some View {
        Section(title) {
            ForEach(presets) { preset in
                themeRow(preset)
            }
        }
    }

    private func themeRow(_ preset: AppTheme) -> some View {
        Button {
            settings.theme = preset
        } label: {
            HStack(spacing: 12) {
                ThemeSwatchView(theme: preset)
                Text(preset.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if settings.theme == preset {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(settings.theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Font

    private var fontSection: some View {
        Section("Font") {
            ForEach(AppFont.allCases) { font in
                Button {
                    settings.font = font
                } label: {
                    HStack(spacing: 12) {
                        Text("Aa")
                            .font(font.font(size: 20))
                            .frame(width: 40)
                        Text(font.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if settings.font == font {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(settings.theme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A live preview of a theme, in ClassMate's own swatch design
/// (`ThemeSwatchView`): a surface card with an accent dot, two "text line"
/// bars, and a paper chip with a hairline separator border.
private struct ThemeSwatchView: View {
    let theme: AppTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(theme.surface)
            .overlay {
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5).fill(theme.ink).frame(width: 34, height: 3)
                        RoundedRectangle(cornerRadius: 1.5).fill(theme.inkSecondary).frame(width: 24, height: 3)
                    }
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(theme.separator, lineWidth: 0.5)
                        )
                        .frame(width: 18, height: 24)
                }
                .padding(.horizontal, 8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme.separator, lineWidth: 0.5)
            )
            .frame(width: 108, height: 44)
            .accessibilityLabel("\(theme.displayName) theme preview")
    }
}

private extension Bundle {
    var appVersionString: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
