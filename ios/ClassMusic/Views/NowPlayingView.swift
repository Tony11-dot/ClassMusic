import SwiftUI

struct NowPlayingView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(\.dismiss) private var dismiss
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                artwork

                if let song = playback.currentSong {
                    VStack(spacing: 4) {
                        Text(song.title)
                            .font(.title2.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(song.artist)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    progressSection
                    transportControls

                    Button {
                        song.isFavorite.toggle()
                    } label: {
                        Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(song.isFavorite ? .pink : .secondary)
                            .font(.title3)
                    }
                } else {
                    ContentUnavailableView("Nothing Playing", systemImage: "music.note")
                }

                Spacer()
            }
            .padding(.top, 32)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var artwork: some View {
        AsyncImage(url: playback.currentSong?.thumbnailURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(.quaternary)
                .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary))
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 12, y: 6)
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubTime : playback.currentTime },
                    set: { scrubTime = $0 }
                ),
                in: 0...max(playback.duration, 1),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing { playback.seek(to: scrubTime) }
                }
            )
            HStack {
                Text(format(isScrubbing ? scrubTime : playback.currentTime))
                Spacer()
                Text(format(playback.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                queueStore.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(queueStore.isShuffled ? Color.accentColor : .secondary)
            }

            Button {
                if let song = queueStore.skipToPrevious() {
                    Task { await playback.play(song: song) }
                }
            } label: {
                Image(systemName: "backward.fill").font(.title)
            }

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }

            Button {
                if let song = queueStore.skipToNext() {
                    Task { await playback.play(song: song) }
                }
            } label: {
                Image(systemName: "forward.fill").font(.title)
            }

            Button {
                cycleRepeatMode()
            } label: {
                Image(systemName: queueStore.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(queueStore.repeatMode == .off ? Color.secondary : Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func cycleRepeatMode() {
        switch queueStore.repeatMode {
        case .off: queueStore.setRepeatMode(.all)
        case .all: queueStore.setRepeatMode(.one)
        case .one: queueStore.setRepeatMode(.off)
        }
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
