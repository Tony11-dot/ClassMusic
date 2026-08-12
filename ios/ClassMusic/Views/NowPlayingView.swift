import SwiftUI

struct NowPlayingView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings
    /// 0...1, shared with the mini player's drag gesture (see ContentView) —
    /// dragging the handle down here continuously collapses back toward the
    /// mini player instead of just dismissing outright.
    @Binding var expansion: CGFloat
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0

    var body: some View {
        VStack(spacing: 24) {
            // The handle, artwork, and title/artist block all share the
            // collapse gesture — not just the small handle — since that's
            // where people actually try to pull down from. The slider and
            // transport buttons keep their own gestures untouched below.
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
            .contentShape(Rectangle())
            .gesture(collapseDragGesture)

            if let song = playback.currentSong {
                progressSection
                transportControls

                Button {
                    song.isFavorite.toggle()
                } label: {
                    Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(song.isFavorite ? .pink : settings.theme.inkSecondary)
                        .font(.title3)
                }
            } else {
                ContentUnavailableView("Nothing Playing", systemImage: "music.note")
            }

            Spacer()
        }
        .padding(.top, 12)
        .foregroundStyle(settings.theme.ink)
    }

    // No gesture attached here directly — it's nested inside the outer
    // VStack, which already carries `collapseDragGesture`. Attaching the
    // same gesture to both a view and its ancestor created two competing
    // recognizers that occasionally swapped mid-drag, producing the
    // stutter/glitch during pull-down.
    private var dragHandle: some View {
        Capsule()
            .fill(settings.theme.inkSecondary.opacity(0.35))
            .frame(width: 44, height: 5)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
    }

    private var collapseDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let dragDown = max(value.translation.height, 0)
                expansion = max(1 - dragDown / 250, 0)
            }
            .onEnded { value in
                let dragDown = max(value.translation.height, 0)
                let predictedDown = max(value.predictedEndTranslation.height, 0)
                // Any deliberate pull (not just a long one) or a flick
                // commits to closing — a short, hesitant drag was
                // snapping right back open before.
                let shouldClose = dragDown > 70 || predictedDown > 140 || expansion < 0.75
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    expansion = shouldClose ? 0 : 1
                }
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
