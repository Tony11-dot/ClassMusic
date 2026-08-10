import SwiftUI

struct ContentView: View {
    @Environment(PlaybackManager.self) private var playback

    var body: some View {
        ZStack(alignment: .bottom) {
            SearchView()
            MiniPlayerView()
        }
        #if DEBUG
        .task {
            // Driven by `SIMCTL_CHILD_UITEST_AUTOPLAY=1 simctl launch ...`
            // so the playback pipeline can be verified from the command
            // line without simulating taps.
            guard ProcessInfo.processInfo.environment["UITEST_AUTOPLAY"] == "1" else { return }
            let song = Song(
                id: "dQw4w9WgXcQ",
                title: "Never Gonna Give You Up",
                artist: "Rick Astley",
                thumbnailURL: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
            )
            await playback.play(song: song)
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environment(PlaybackManager())
}
