import SwiftData
import SwiftUI

@main
struct ClassMusicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let modelContainer: ModelContainer
    @State private var playbackManager = PlaybackManager()
    @State private var queueStore: QueueStore
    @State private var settings = AppSettings()
    @State private var showLaunch = true

    init() {
        let schema = Schema([
            Song.self,
            Playlist.self,
            PlaylistItem.self,
            PlaybackQueue.self,
            QueueItem.self,
        ])
        // Stored in the App Group container so the widget extension can
        // read from the same store if it ever needs more than the
        // lightweight now-playing snapshot in AppGroup.defaults.
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.id)
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        ModelContainerHolder.shared = modelContainer
        _queueStore = State(initialValue: QueueStore(context: modelContainer.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunch {
                    LaunchView(theme: settings.theme) {
                        withAnimation(.easeOut(duration: 0.25)) { showLaunch = false }
                    }
                    .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .environment(playbackManager)
            .environment(queueStore)
            .environment(settings)
            .tint(settings.theme.accent)
            .preferredColorScheme(settings.theme.colorScheme)
            .environment(\.font, settings.font.font(size: 17))
        }
        .modelContainer(modelContainer)
    }
}
