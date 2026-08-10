import Foundation
import Observation
import SwiftData

/// Owns the single persistent PlaybackQueue row. PlaybackManager doesn't
/// know this exists — ContentView wires PlaybackManager's onTrackFinished/
/// onSkipNext/onSkipPrevious closures to the advance methods here, keeping
/// "how to play a URL" and "what plays next" as separate concerns.
@Observable
@MainActor
final class QueueStore {
    /// CarPlaySceneDelegate runs as a separate scene delegate outside the
    /// SwiftUI environment, so it looks this up rather than being handed
    /// one via @Environment.
    static weak var shared: QueueStore?

    private(set) var songs: [Song] = []
    private(set) var currentIndex: Int = 0
    private(set) var repeatMode: RepeatMode = .off
    private(set) var isShuffled = false

    private let context: ModelContext
    private var queue: PlaybackQueue

    init(context: ModelContext) {
        self.context = context
        if let existing = try? context.fetch(FetchDescriptor<PlaybackQueue>()).first {
            queue = existing
        } else {
            let created = PlaybackQueue()
            context.insert(created)
            queue = created
        }
        refresh()
        Self.shared = self
    }

    private func refresh() {
        let ordered = queue.orderedItems
        songs = ordered.compactMap(\.song)
        currentIndex = queue.currentIndex
        repeatMode = queue.repeatMode
        isShuffled = queue.isShuffled
    }

    private func renumber() {
        for (index, item) in queue.orderedItems.enumerated() {
            item.position = index
        }
    }

    var currentSong: Song? {
        songs.indices.contains(currentIndex) ? songs[currentIndex] : nil
    }

    func enqueue(_ song: Song) {
        let nextPosition = queue.items.map(\.position).max().map { $0 + 1 } ?? 0
        let item = QueueItem(song: song, position: nextPosition)
        context.insert(item)
        // Appending through the relationship (not just setting item.queue)
        // is what makes SwiftData wire up the inverse correctly.
        queue.items.append(item)
        refresh()
    }

    func remove(at index: Int) {
        let ordered = queue.orderedItems
        guard ordered.indices.contains(index) else { return }
        context.delete(ordered[index])
        renumber()
        if currentIndex > index {
            queue.currentIndex -= 1
        }
        refresh()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = queue.orderedItems
        let playingItem = ordered.indices.contains(currentIndex) ? ordered[currentIndex] : nil
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.position = index
        }
        if let playingItem, let newIndex = ordered.firstIndex(where: { $0.id == playingItem.id }) {
            queue.currentIndex = newIndex
        }
        refresh()
    }

    func setRepeatMode(_ mode: RepeatMode) {
        queue.repeatMode = mode
        refresh()
    }

    func toggleShuffle() {
        queue.isShuffled.toggle()
        if queue.isShuffled {
            let ordered = queue.orderedItems
            let playingItem = ordered.indices.contains(currentIndex) ? ordered[currentIndex] : nil
            var rest = ordered.filter { $0.id != playingItem?.id }
            rest.shuffle()
            let newOrder = [playingItem].compactMap { $0 } + rest
            for (index, item) in newOrder.enumerated() {
                item.position = index
            }
            queue.currentIndex = 0
        }
        refresh()
    }

    /// Jump directly to a queue row (tapped in QueueView).
    func jump(to index: Int) -> Song? {
        guard songs.indices.contains(index) else { return nil }
        queue.currentIndex = index
        refresh()
        return songs[index]
    }

    /// Explicit "skip" — always advances, regardless of repeat-one.
    func skipToNext() -> Song? {
        advance(from: currentIndex + 1, wrapping: repeatMode == .all)
    }

    func skipToPrevious() -> Song? {
        advance(from: currentIndex - 1, wrapping: repeatMode == .all)
    }

    /// Auto-advance when a track finishes on its own — repeat-one replays.
    func handleTrackFinished() -> Song? {
        if repeatMode == .one, let currentSong {
            return currentSong
        }
        return advance(from: currentIndex + 1, wrapping: repeatMode == .all)
    }

    private func advance(from index: Int, wrapping: Bool) -> Song? {
        guard !songs.isEmpty else { return nil }
        var target = index
        if target < 0 {
            target = wrapping ? songs.count - 1 : 0
        } else if target >= songs.count {
            guard wrapping else { return nil }
            target = 0
        }
        queue.currentIndex = target
        refresh()
        return songs[target]
    }
}
