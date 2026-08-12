import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    /// 0 = collapsed (mini player), 1 = fully expanded (full-screen player).
    /// Driven continuously by the drag gesture below, not just an on/off
    /// toggle, so the mini bar can be dragged open with the player tracking
    /// the gesture the whole way instead of jumping straight to a sheet.
    @State private var playerExpansion: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(0)
                LibraryView()
                    .tabItem { Label("Library", systemImage: "music.note.list") }
                    .tag(1)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(2)
            }
            .tint(settings.theme.accent)
            .onAppear { applyTabBarFont() }
            .onChange(of: settings.font) { _, _ in applyTabBarFont() }

            MiniPlayerView()
                .padding(.bottom, 49 + 10)  // clear the tab bar, plus a floating gap above it
                .opacity(1 - playerExpansion)
                .allowsHitTesting(playerExpansion < 0.05)
                .simultaneousGesture(playerDragGesture)
                .onTapGesture { expand() }
        }
        .background(settings.theme.surface.ignoresSafeArea())
        .overlay {
            if playback.currentSong != nil {
                GeometryReader { geo in
                    NowPlayingView(expansion: $playerExpansion)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(settings.theme.surface)
                        .offset(y: (1 - playerExpansion) * geo.size.height)
                        // No opacity toggle here on purpose: a hard 0/1 cutoff
                        // at a fixed threshold flickered whenever ordinary
                        // finger jitter crossed back and forth over it right
                        // at the end of a drag. The offset alone already
                        // parks the view fully off-screen at expansion 0.
                        // Must stay hit-testable for as long as the view is
                        // even partly visible — gating this on a >0.5
                        // threshold cut hit-testing out from under an
                        // in-progress drag the moment it crossed halfway,
                        // which is exactly what broke "pull down to collapse".
                        .allowsHitTesting(playerExpansion > 0.01)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .alert("Couldn't play track", isPresented: loadErrorBinding, presenting: playback.loadError) { _ in
            Button("OK") { playback.clearLoadError() }
        } message: { message in
            Text(message)
        }
        .task {
            wireQueueToPlayback()
            #if DEBUG
            await autoplayIfRequested()
            exerciseLibraryIfRequested()
            expandPlayerIfRequested()
            if ProcessInfo.processInfo.environment["UITEST_SETTINGS_TAB"] == "1" { selectedTab = 2 }
            #endif
        }
    }

    private var playerDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dragUp = -value.translation.height
                playerExpansion = min(max(dragUp / 300, 0), 1)
            }
            .onEnded { value in
                let predictedUp = -value.predictedEndTranslation.height
                let shouldOpen = playerExpansion > 0.35 || predictedUp > 220
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    playerExpansion = shouldOpen ? 1 : 0
                }
            }
    }

    /// `UITabBarItem` renders through UIKit and ignores SwiftUI's `.font`
    /// environment entirely, so the chosen font would otherwise never reach
    /// the tab bar labels — this is the one place that has to go through
    /// the UIKit appearance proxy instead, reapplied whenever the font
    /// changes since the proxy doesn't observe SwiftUI state on its own.
    private func applyTabBarFont() {
        let font = settings.font.uiFont(size: 10, weight: .medium)
        let appearance = UITabBarItem.appearance()
        appearance.setTitleTextAttributes([.font: font], for: .normal)
        appearance.setTitleTextAttributes([.font: font], for: .selected)
    }

    private func expand() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            playerExpansion = 1
        }
    }

    private var loadErrorBinding: Binding<Bool> {
        Binding(
            get: { playback.loadError != nil },
            set: { if !$0 { playback.clearLoadError() } }
        )
    }

    private func wireQueueToPlayback() {
        playback.onTrackFinished = {
            guard let next = queueStore.handleTrackFinished() else { return }
            Task { await playback.play(song: next) }
        }
        playback.onSkipNext = {
            guard let next = queueStore.skipToNext() else { return }
            Task { await playback.play(song: next) }
        }
        playback.onSkipPrevious = {
            guard let previous = queueStore.skipToPrevious() else { return }
            Task { await playback.play(song: previous) }
        }
    }

    #if DEBUG
    private func autoplayIfRequested() async {
        // Driven by `SIMCTL_CHILD_UITEST_AUTOPLAY=1 simctl launch ...` so
        // the playback pipeline can be verified from the command line
        // without simulating taps.
        guard ProcessInfo.processInfo.environment["UITEST_AUTOPLAY"] == "1" else { return }
        let song = Song(
            id: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            artist: "Rick Astley",
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        )
        await playback.play(song: song)
    }

    /// Driven by `SIMCTL_CHILD_UITEST_LIBRARY=1` — exercises playlist
    /// creation, queueing, and favoriting through QueueStore/modelContext
    /// directly (bypassing UI taps, which can't be scripted here) so a
    /// SwiftData relationship bug surfaces as a crash log, not silently.
    private func exerciseLibraryIfRequested() {
        guard ProcessInfo.processInfo.environment["UITEST_LIBRARY"] == "1" else { return }
        selectedTab = 1

        let song = Song(
            id: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            artist: "Rick Astley",
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        )
        modelContext.insert(song)
        song.isFavorite = true

        let playlist = Playlist(name: "UITest Playlist", sortOrder: 0)
        modelContext.insert(playlist)
        let item = PlaylistItem(song: song, position: 0)
        modelContext.insert(item)
        playlist.items.append(item)

        queueStore.enqueue(song)
    }

    /// Driven by `SIMCTL_CHILD_UITEST_EXPAND_PLAYER=1` — jumps straight to
    /// the full player since `devicectl`/`simctl` have no way to simulate
    /// the drag-to-expand gesture itself.
    private func expandPlayerIfRequested() {
        guard ProcessInfo.processInfo.environment["UITEST_EXPAND_PLAYER"] == "1" else { return }
        playerExpansion = 1
    }
    #endif
}
