import SwiftUI

/// The shared track-row layout used everywhere a song appears in a list
/// (Search results, playlists, Favorites, Queue, Recently Played) — one
/// place to keep that look consistent instead of near-duplicate rows per
/// screen. Bigger, softly-rounded artwork and no boxed row background is
/// what actually reads as "modern" here, not just different corner radii —
/// callers pair this with `.listRowBackground(Color.clear)` so the row sits
/// directly on the screen background rather than inside a card.
struct SongRow: View {
    @Environment(AppSettings.self) private var settings
    let title: String
    let artist: String
    let thumbnailURL: URL?
    let isFavorite: Bool

    init(song: Song) {
        self.title = song.title
        self.artist = song.artist
        self.thumbnailURL = song.thumbnailURL
        self.isFavorite = song.isFavorite
    }

    init(title: String, artist: String, thumbnailURL: URL?, isFavorite: Bool = false) {
        self.title = title
        self.artist = artist
        self.thumbnailURL = thumbnailURL
        self.isFavorite = isFavorite
    }

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(settings.font.font(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(artist)
                    .font(settings.font.font(size: 13))
                    .foregroundStyle(settings.theme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
