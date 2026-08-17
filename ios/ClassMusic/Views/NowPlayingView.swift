import SwiftUI

struct NowPlayingView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings
    @Binding var isExpanded: Bool
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var showAddToPlaylist = false

    var body: some View {
        ZStack {
            // A single drag-catcher behind everything, covering the full
            // view (including blank space below the controls) rather than
            // only the handle/artwork/title block — buttons and the slider
            // still claim their own touches first. It only *reads* the
            // gesture at release (see collapseGesture) instead of tracking
            // it live frame-by-frame, which was the real source of the
            // "stuck image, shifting" stutter reported on-device: every
            // touch-move was re-rendering this whole (heavy) view at a new
            // offset/opacity, dozens of times a second. Deciding once and
            // letting a single spring animate it is what actually reads as
            // smooth.
            Color.clear
                .contentShape(Rectangle())
                .gesture(collapseGesture)

            VStack(spacing: 24) {
                VStack(spacing: 24) {
                    dragHandle
                    artwork
                    if let song = playback.currentSong {
                        VStack(spacing: 4) {
                            Text(song.title)
                                .font(settings.font.font(size: 22, weight: .bold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text(song.artist)
                                .font(settings.font.font(size: 20))
                                .foregroundStyle(settings.theme.inkSecondary)
                        }
                        .padding(.horizontal)
                    }
                }

                if let song = playback.currentSong {
                    progressSection
                    transportControls

                    HStack(spacing: 28) {
                        Button {
                            song.isFavorite.toggle()
                        } label: {
                            Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(song.isFavorite ? .pink : settings.theme.inkSecondary)
                                .font(.title3)
                        }

                        Button {
                            showAddToPlaylist = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(settings.theme.inkSecondary)
                                .font(.title3)
                        }
                    }
                } else {
                    ContentUnavailableView("Nothing Playing", systemImage: "music.note")
                }

                Spacer()
            }
            .padding(.top, 12)
            .allowsHitTesting(true)
        }
        .foregroundStyle(settings.theme.ink)
        .sheet(isPresented: $showAddToPlaylist) {
            if let song = playback.currentSong {
                AddToPlaylistSheet(song: song)
            }
        }
    }

    // A plain tap here is a guaranteed-reliable, gesture-conflict-free way
    // to collapse — no drag tracking involved at all, just a button. The
    // drag below still works from anywhere in the view, but this is the
    // fallback that can't glitch.
    private var dragHandle: some View {
        Capsule()
            .fill(settings.theme.inkSecondary.opacity(0.35))
            .frame(width: 44, height: 5)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { collapse() }
    }

    /// Reads the gesture only at release, not on every touch-move — see the
    /// comment on the drag-catcher above.
    private var collapseGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dragDown = max(value.translation.height, 0)
                let predictedDown = max(value.predictedEndTranslation.height, 0)
                if dragDown > 40 || predictedDown > 120 {
                    collapse()
                }
            }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isExpanded = false
        }
    }

    private var artwork: some View {
        AsyncImage(url: playback.currentSong?.thumbnailURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(settings.theme.surfaceRaised)
                .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(settings.theme.inkSecondary))
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
            .font(settings.font.font(size: 12))
            .foregroundStyle(settings.theme.inkSecondary)
        }
        .padding(.horizontal)
    }

    private var transportControls: some View {
        HStack(spacing: 14) {
            glassButton("shuffle", size: 13, dimension: 34, active: queueStore.isShuffled) {
                queueStore.toggleShuffle()
            }

            glassButton("backward.fill", size: 17, dimension: 46) {
                if let song = queueStore.skipToPrevious() {
                    Task { await playback.play(song: song) }
                }
            }

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.glassProminent)
            .tint(settings.theme.accent)
            .frame(width: 60, height: 60)
            .clipShape(Circle())

            glassButton("forward.fill", size: 17, dimension: 46) {
                if let song = queueStore.skipToNext() {
                    Task { await playback.play(song: song) }
                }
            }

            glassButton(
                queueStore.repeatMode == .one ? "repeat.1" : "repeat",
                size: 13, dimension: 34, active: queueStore.repeatMode != .off
            ) {
                cycleRepeatMode()
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// A single Liquid Glass transport control — native `.glass` button
    /// material (matching the mini player's `.glassEffect` chrome) instead
    /// of a plain tinted SF Symbol, with the theme accent standing in for
    /// system tint so it still reads as "on" per-theme. The explicit
    /// `.frame` *after* `.buttonStyle`/`.clipShape` matters: the glass style
    /// adds its own chrome padding around the label, which otherwise makes
    /// the button wider than the frame set on the label alone and pushes
    /// the outer buttons off the edge of the row.
    private func glassButton(
        _ systemImage: String, size: CGFloat, dimension: CGFloat, active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? settings.theme.accent : settings.theme.ink)
                .frame(width: dimension, height: dimension)
        }
        .buttonStyle(.glass)
        .frame(width: dimension, height: dimension)
        .clipShape(Circle())
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
