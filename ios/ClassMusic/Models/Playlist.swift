import Foundation
import SwiftData

@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \PlaylistItem.playlist)
    var items: [PlaylistItem] = []

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.sortOrder = sortOrder
    }

    var orderedItems: [PlaylistItem] {
        items.sorted { $0.position < $1.position }
    }
}

@Model
final class PlaylistItem {
    @Attribute(.unique) var id: UUID
    var position: Int
    var song: Song?
    var playlist: Playlist?

    init(song: Song, position: Int) {
        self.id = UUID()
        self.song = song
        self.position = position
    }
}
