import SwiftData
import SwiftUI

struct AddToPlaylistSheet: View {
    let song: Song

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(playlists) { playlist in
                        Button {
                            add(song, to: playlist)
                        } label: {
                            Label(playlist.name, systemImage: "music.note.list")
                        }
                    }
                }
                Section("New Playlist") {
                    HStack {
                        TextField("Playlist name", text: $newPlaylistName)
                        Button("Create") {
                            let playlist = Playlist(name: newPlaylistName, sortOrder: playlists.count)
                            modelContext.insert(playlist)
                            add(song, to: playlist)
                        }
                        .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func add(_ song: Song, to playlist: Playlist) {
        let position = playlist.items.map(\.position).max().map { $0 + 1 } ?? 0
        let item = PlaylistItem(song: song, position: position)
        modelContext.insert(item)
        // Appending through the relationship (rather than only setting
        // item.playlist) is what makes SwiftData wire up the inverse.
        playlist.items.append(item)
        dismiss()
    }
}
