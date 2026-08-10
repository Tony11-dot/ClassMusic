import SwiftUI
import WidgetKit

// Placeholder — replaced with the full now-playing widget (all sizes, Lock
// Screen accessories, StandBy) once the app-side playback/App Group state
// this will read actually exists.

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

struct ClassMusicWidgetEntryView: View {
    var entry: PlaceholderProvider.Entry

    var body: some View {
        Text("ClassMusic")
            .font(.caption.bold())
    }
}

struct ClassMusicWidget: Widget {
    let kind = "ClassMusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            ClassMusicWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ClassMusic")
        .description("Shows the current track.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct ClassMusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClassMusicWidget()
    }
}
