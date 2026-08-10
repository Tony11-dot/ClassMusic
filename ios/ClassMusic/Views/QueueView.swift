import SwiftUI

struct QueueView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore

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

            if queueStore.songs.isEmpty {
                ContentUnavailableView("Queue is Empty", systemImage: "text.line.first.and.arrowtriangle.forward", description: Text("Add songs from Search."))
            }

            ForEach(Array(queueStore.songs.enumerated()), id: \.element.id) { index, song in
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
                }
                .buttonStyle(.plain)
                .listRowBackground(index == queueStore.currentIndex ? Color.accentColor.opacity(0.12) : nil)
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
