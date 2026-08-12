import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: FavoritesView()) {
                        Label("Favorites", systemImage: "heart.fill")
                            .foregroundStyle(.pink)
                    }
                    NavigationLink(destination: QueueView()) {
                        Label("Queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                            .foregroundStyle(.blue)
                    }
                }
                .listRowBackground(settings.theme.surfaceRaised)

                Section("Playlists") {
                    if playlists.isEmpty {
                        ContentUnavailableView("No Playlists", systemImage: "music.note.list")
                    }
                    ForEach(playlists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                Text("\(playlist.items.count) songs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                }
                .listRowBackground(settings.theme.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(settings.theme.surface)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Playlist", systemImage: "plus") {
                        newPlaylistName = ""
                        isCreatingPlaylist = true
                    }
                }
            }
            .alert("New Playlist", isPresented: $isCreatingPlaylist) {
                TextField("Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    modelContext.insert(Playlist(name: trimmed, sortOrder: playlists.count))
                }
            }
        }
    }

    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(playlists[index])
        }
    }
}
