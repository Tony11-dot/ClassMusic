import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(\.modelContext) private var modelContext
    @State private var showNowPlaying = false
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

            MiniPlayerView()
                .padding(.bottom, 49)  // clear the tab bar
                .onTapGesture { showNowPlaying = true }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
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
            #endif
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
    #endif
}
