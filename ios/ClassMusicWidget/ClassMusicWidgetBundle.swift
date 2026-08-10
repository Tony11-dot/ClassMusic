import SwiftUI
import WidgetKit

struct NowPlayingWidget: Widget {
    let kind = "NowPlayingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the current track with play/pause/skip controls.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

@main
struct ClassMusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}
