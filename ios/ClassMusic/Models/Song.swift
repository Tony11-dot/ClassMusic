import Foundation
import SwiftData

@Model
final class Song {
    @Attribute(.unique) var id: String  // YouTube video ID
    var title: String
    var artist: String
    var thumbnailURL: URL?
    var duration: TimeInterval?
    var dateAdded: Date
    var isFavorite: Bool

    init(
        id: String,
        title: String,
        artist: String,
        thumbnailURL: URL? = nil,
        duration: TimeInterval? = nil,
        dateAdded: Date = .now,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
    }
}
