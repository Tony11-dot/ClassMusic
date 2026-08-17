import SwiftUI

struct QueueView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        queueStore.toggleShuffle()
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .foregroundStyle(queueStore.isShuffled ? Color.accentColor : .primary)
                    }
                    Spacer()
                    Button {
                        cycleRepeatMode()
                    } label: {
                        Label("Repeat", systemImage: repeatIcon)
                            .foregroundStyle(queueStore.repeatMode == .off ? Color.primary : Color.accentColor)
                    }
                }
                .buttonStyle(.borderless)
            }
            .listRowBackground(settings.theme.surfaceRaised)

            if queueStore.songs.isEmpty {
                ContentUnavailableView("Queue is Empty", systemImage: "text.line.first.and.arrowtriangle.forward", description: Text("Add songs from Search."))
            }

            // Keyed by position, not `song.id`: the same song can legitimately
            // appear twice in the queue (added from two different places), and
            // `Song.id` (the YouTube video ID) is shared by both rows in that
            // case. Keying a List/ForEach by a non-unique id makes SwiftUI's
            // diffing misattribute swipe-to-delete/drag-to-reorder between the
            // duplicate rows — the queue looking "out of order" or "skipping"
            // after a delete/move was this, not the underlying data.
            ForEach(Array(queueStore.songs.enumerated()), id: \.offset) { index, song in
                Button {
                    guard let jumped = queueStore.jump(to: index) else { return }
                    Task { await playback.play(song: jumped) }
                } label: {
                    HStack {
                        SongRow(song: song)
                        if index == queueStore.currentIndex, playback.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(index == queueStore.currentIndex ? settings.theme.accent.opacity(0.12) : Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                for index in offsets.sorted(by: >) {
                    queueStore.remove(at: index)
                }
            }
            .onMove { source, destination in
                queueStore.move(fromOffsets: source, toOffset: destination)
            }
        }
        .scrollContentBackground(.hidden)
        .background(settings.theme.surface)
        .toolbar { EditButton() }
        .navigationTitle("Queue")
    }

    private var repeatIcon: String {
        switch queueStore.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private func cycleRepeatMode() {
        switch queueStore.repeatMode {
        case .off: queueStore.setRepeatMode(.all)
        case .all: queueStore.setRepeatMode(.one)
        case .one: queueStore.setRepeatMode(.off)
        }
    }
}
