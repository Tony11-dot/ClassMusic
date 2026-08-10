import Foundation
import SwiftData

enum RepeatMode: String, Codable {
    case off, all, one
}

/// Singleton row — there is exactly one persistent queue. PlaybackManager
/// fetches (or creates) it on launch and mutates it in place.
@Model
final class PlaybackQueue {
    var currentIndex: Int
    var repeatMode: RepeatMode
    var isShuffled: Bool

    @Relationship(deleteRule: .cascade, inverse: \QueueItem.queue)
    var items: [QueueItem] = []

    init(currentIndex: Int = 0, repeatMode: RepeatMode = .off, isShuffled: Bool = false) {
        self.currentIndex = currentIndex
        self.repeatMode = repeatMode
        self.isShuffled = isShuffled
    }

    var orderedItems: [QueueItem] {
        items.sorted { $0.position < $1.position }
    }

    var currentItem: QueueItem? {
        let ordered = orderedItems
        guard currentIndex >= 0, currentIndex < ordered.count else { return nil }
        return ordered[currentIndex]
    }
}

@Model
final class QueueItem {
    @Attribute(.unique) var id: UUID
    var position: Int
    var song: Song?
    var queue: PlaybackQueue?

    init(song: Song, position: Int) {
        self.id = UUID()
        self.song = song
        self.position = position
    }
}
