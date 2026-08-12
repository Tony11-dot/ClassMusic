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
                presetSection(title: "Light themes", presets: [.system] + AppTheme.lightFamily)
                presetSection(title: "Dark themes", presets: AppTheme.darkFamily)
                fontSection
                Text("Version \(Bundle.main.appVersionString)")
                    .font(settings.font.font(size: 12))
                    .foregroundStyle(settings.theme.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(settings.theme.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // In the nav bar itself, not a List safeAreaInset — the
                // same lockup, the same placement, on every screen.
                ToolbarItem(placement: .principal) { BrandHeaderBar() }
            }
        }
    }

    // MARK: - Theme

    private func presetSection(title: String, presets: [AppTheme]) -> some View {
        Section {
            ForEach(presets) { preset in
                themeRow(preset)
            }
        } header: {
            Text(title).font(settings.font.font(size: 13))
        }
        .listRowBackground(settings.theme.surfaceRaised)
    }

    private func themeRow(_ preset: AppTheme) -> some View {
        Button {
            settings.theme = preset
        } label: {
            HStack(spacing: 12) {
                ThemeSwatchView(theme: preset)
                Text(preset.displayName)
                    .foregroundStyle(settings.theme.ink)
                Spacer(minLength: 0)
                if settings.theme == preset {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(settings.theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Font

    private var fontSection: some View {
        Section {
            ForEach(AppFont.allCases) { font in
                Button {
                    settings.font = font
                } label: {
                    HStack(spacing: 12) {
                        Text("Aa")
                            .font(font.font(size: 20))
                            .frame(width: 40)
                        Text(font.displayName)
                            .foregroundStyle(settings.theme.ink)
                        Spacer(minLength: 0)
                        if settings.font == font {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(settings.theme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Font").font(settings.font.font(size: 13))
        }
        .listRowBackground(settings.theme.surfaceRaised)
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
