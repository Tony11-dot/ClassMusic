import Foundation

/// What the widget extension actually reads. Widgets run in a separate
/// process with a strict CPU/time budget, so this is a small JSON blob in
/// the App Group's shared UserDefaults rather than a SwiftData fetch —
/// artwork is a locally-cached file in the App Group container, since
/// widgets shouldn't be doing their own network fetches either.
struct NowPlayingSnapshot: Codable, Equatable {
    var songId: String?
    var title: String
    var artist: String
    var isPlaying: Bool
    var elapsed: TimeInterval
    var duration: TimeInterval
    var updatedAt: Date
    var artworkFileName: String?

    static let empty = NowPlayingSnapshot(
        songId: nil, title: "Not Playing", artist: "", isPlaying: false,
        elapsed: 0, duration: 0, updatedAt: .now, artworkFileName: nil
    )
}

enum NowPlayingStore {
    private static let key = "nowPlayingSnapshot"

    static func save(_ snapshot: NowPlayingSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func load() -> NowPlayingSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    static func artworkURL(fileName: String) -> URL {
        AppGroup.containerURL.appendingPathComponent(fileName)
    }
}
