import Foundation
import SwiftData

enum SongRepository {
    /// Search results are transient (YouTubeSearchResult); anything that
    /// needs to persist (favorite, playlist, queue) needs an actual `Song`
    /// row. Reuses an existing row for the same video ID instead of
    /// violating the unique constraint on `Song.id`.
    static func upsert(from result: YouTubeSearchResult, context: ModelContext) -> Song {
        let id = result.id
        if let existing = try? context.fetch(
            FetchDescriptor<Song>(predicate: #Predicate { $0.id == id })
        ).first {
            return existing
        }
        let song = Song(
            id: result.id,
            title: result.title,
            artist: result.artist,
            thumbnailURL: result.thumbnailURL
        )
        context.insert(song)
        return song
    }
}
