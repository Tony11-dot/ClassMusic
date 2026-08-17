import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(QueueStore.self) private var queueStore
    @Environment(PlaybackManager.self) private var playback
    @State private var selectedTab = 0

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

            // Isolated into its own view so the drag gesture's continuous
            // state updates only re-evaluate this small subtree, not the
            // whole TabView (three tabs, one a searchable List) on every
            // frame of the drag — that full-tree re-evaluation was the
            // source of the expand/collapse lag.
            PlayerOverlay()
        }
        .background(settings.theme.surface.ignoresSafeArea())
        .alert("Couldn't play track", isPresented: loadErrorBinding, presenting: playback.loadError) { _ in
            Button("OK") { playback.clearLoadError() }
        } message: { message in
            Text(message)
        }
        .task {
            wireQueueToPlayback()
            Task { await playback.prewarm() }
            #if DEBUG
            await autoplayIfRequested()
            exerciseLibraryIfRequested()
            if ProcessInfo.processInfo.environment["UITEST_SETTINGS_TAB"] == "1" { selectedTab = 2 }
            #endif
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
    #endif
}

/// Owns the mini/full player's continuous expansion state so dragging it
/// only re-evaluates this small view, not the tab bar and its three tabs.
/// Also draws *after* (so, visually on top of) the full player in the
/// parent ZStack — the full player is a full-screen view that slides down
/// and out via `offset`, and without the mini bar layered on top of it,
/// the sliver of the full player still on-screen mid-drag (its drag handle,
/// being the first thing in its own layout) showed through right on top of
/// the mini bar/tab bar instead of being covered by it.
private struct PlayerOverlay: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(AppSettings.self) private var settings
    /// Binary, not a continuously-tracked 0...1 value. The previous version
    /// updated a fractional `expansion` on every touch-move during the
    /// drag, which meant every finger movement re-rendered the full (heavy)
    /// NowPlayingView subtree at a new offset/opacity — on a real device
    /// that per-frame work was visibly janky ("stuck image, shifting"),
    /// not just a gesture-conflict bug. Deciding open/closed once — on a
    /// tap, or by reading the drag only at release — and letting a single
    /// `withAnimation` spring interpolate the change is what actually
    /// reads as smooth: one state change, system-driven, instead of dozens
    /// of hand-computed intermediate frames.
    @State private var isExpanded = false

    var body: some View {
        Group {
            if playback.currentSong != nil {
                GeometryReader { geo in
                    NowPlayingView(isExpanded: $isExpanded)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(settings.theme.surface)
                        .offset(y: isExpanded ? 0 : geo.size.height)
                        .opacity(isExpanded ? 1 : 0)
                        .allowsHitTesting(isExpanded)
                        .ignoresSafeArea(edges: .bottom)
                }
            }

            MiniPlayerView()
                .padding(.bottom, 49 + 10)  // clear the tab bar, plus a floating gap above it
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(!isExpanded)
                .simultaneousGesture(openGesture)
                .onTapGesture { setExpanded(true) }
        }
        #if DEBUG
        .task { expandIfRequested() }
        #endif
    }

    /// Only reads the gesture at release — no live tracking, see above.
    private var openGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dragUp = -value.translation.height
                let predictedUp = -value.predictedEndTranslation.height
                if dragUp > 40 || predictedUp > 120 {
                    setExpanded(true)
                }
            }
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isExpanded = expanded
        }
    }

    #if DEBUG
    /// Driven by `SIMCTL_CHILD_UITEST_EXPAND_PLAYER=1` — jumps straight to
    /// the full player since `devicectl`/`simctl` have no way to simulate
    /// the drag-to-expand gesture itself.
    private func expandIfRequested() {
        guard ProcessInfo.processInfo.environment["UITEST_EXPAND_PLAYER"] == "1" else { return }
        isExpanded = true
    }
    #endif
}
