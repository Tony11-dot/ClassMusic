import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if let song = playback.currentSong {
            HStack(spacing: 12) {
                AsyncImage(url: song.thumbnailURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(song.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if playback.isBuffering {
                    BrandLoader(size: 32, tint: settings.theme.accent)
                } else {
                    Button {
                        playback.togglePlayPause()
                    } label: {
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .foregroundStyle(settings.theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
    }
}
