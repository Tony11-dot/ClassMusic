import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(NowPlayingEntry(date: .now, snapshot: NowPlayingStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        // No periodic refresh schedule: the app calls
        // WidgetCenter.shared.reloadAllTimelines() itself on every playback
        // state change, so a single entry with .never is the correct policy
        // here rather than guessing a refresh interval.
        let entry = NowPlayingEntry(date: .now, snapshot: NowPlayingStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}
