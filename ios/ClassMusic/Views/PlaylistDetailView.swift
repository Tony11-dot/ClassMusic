import SwiftData
import SwiftUI

struct PlaylistDetailView: View {
    @Bindable var playlist: Playlist

    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var isRenaming = false
    @State private var renameText = ""

    private var items: [PlaylistItem] { playlist.orderedItems }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView("No Songs", systemImage: "music.note.list", description: Text("Add songs from Search."))
            }
            ForEach(items) { item in
                if let song = item.song {
                    Button {
                        // See SearchView's equivalent comment — playing the
                        // whole playlist as context (not just this one song)
                        // is what makes Next/Previous/Repeat walk through
                        // the playlist afterward.
                        let songs = items.compactMap(\.song)
                        guard let index = songs.firstIndex(where: { $0.id == song.id }),
                              let toPlay = queueStore.playNow(songs, startingAt: index) else { return }
                        Task { await playback.play(song: toPlay) }
                    } label: {
                        SongRow(song: song)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            remove(item)
                        }
                        Button("Queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
                            queueStore.enqueue(song)
                        }
                        .tint(.blue)
                    }
                }
            }
            .onMove(perform: move)
        }
        .scrollContentBackground(.hidden)
        .background(settings.theme.surface)
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        renameText = playlist.name
                        isRenaming = true
                    }
                    EditButton()
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Playlist", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { playlist.name = trimmed }
            }
        }
    }

    private func remove(_ item: PlaylistItem) {
        modelContext.delete(item)
        renumber()
    }

    private func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.position = index
        }
    }

    private func renumber() {
        for (index, item) in playlist.orderedItems.enumerated() {
            item.position = index
        }
    }
}
