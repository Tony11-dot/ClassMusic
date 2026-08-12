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

                Section {
                    if playlists.isEmpty {
                        ContentUnavailableView("No Playlists", systemImage: "music.note.list")
                    }
                    ForEach(playlists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                Text("\(playlist.items.count) songs")
                                    .font(settings.font.font(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                } header: {
                    Text("Playlists").font(settings.font.font(size: 13))
                }
                .listRowBackground(settings.theme.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(settings.theme.surface)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // The `.principal` placement replaces the default "Library"
                // title text with the shared brand lockup (in the nav bar
                // itself, same as every other screen); `navigationTitle`
                // stays set purely so pushed screens still get "Library" as
                // their back-button label.
                ToolbarItem(placement: .principal) { BrandHeaderBar() }
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
