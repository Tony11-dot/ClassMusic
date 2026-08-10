import AppIntents
import WidgetKit

/// These run in the widget extension process, so they can't touch the
/// app's AVPlayer directly — see WidgetCommand for how the signal actually
/// reaches PlaybackManager.
struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource { "Play/Pause" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        WidgetCommand.togglePlayPause.post()
        // Flip optimistically so the widget reflects the tap immediately,
        // ahead of the app's own round-trip update.
        var snapshot = NowPlayingStore.load()
        snapshot.isPlaying.toggle()
        NowPlayingStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SkipNextIntent: AppIntent {
    static var title: LocalizedStringResource { "Next Track" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        WidgetCommand.skipNext.post()
        return .result()
    }
}

struct SkipPreviousIntent: AppIntent {
    static var title: LocalizedStringResource { "Previous Track" }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        WidgetCommand.skipPrevious.post()
        return .result()
    }
}
