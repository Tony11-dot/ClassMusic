import SwiftData
import SwiftUI

struct FavoritesView: View {
    @Environment(PlaybackManager.self) private var playback
    @Environment(QueueStore.self) private var queueStore
    @Environment(AppSettings.self) private var settings
    @Query(filter: #Predicate<Song> { $0.isFavorite }, sort: \Song.dateAdded, order: .reverse)
    private var favorites: [Song]

    var body: some View {
        List {
            if favorites.isEmpty {
                ContentUnavailableView("No Favorites Yet", systemImage: "heart", description: Text("Tap the heart on any song to add it here."))
            }
            ForEach(favorites) { song in
                Button {
                    guard let index = favorites.firstIndex(where: { $0.id == song.id }),
                          let toPlay = queueStore.playNow(favorites, startingAt: index) else { return }
                    Task { await playback.play(song: toPlay) }
                } label: {
                    SongRow(song: song)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions {
                    Button("Unfavorite", systemImage: "heart.slash") {
                        song.isFavorite = false
                    }
                    .tint(.pink)
                    Button("Queue", systemImage: "text.line.first.and.arrowtriangle.forward") {
                        queueStore.enqueue(song)
                    }
                    .tint(.blue)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(settings.theme.surface)
        .navigationTitle("Favorites")
    }
}
