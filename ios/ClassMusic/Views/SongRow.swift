import SwiftUI

struct SongRow: View {
    @Environment(AppSettings.self) private var settings
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: song.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .lineLimit(1)
                Text(song.artist)
                    .font(settings.font.font(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if song.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
